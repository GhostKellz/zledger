const std = @import("std");
const tx = @import("tx.zig");
const account = @import("account.zig");
const journal = @import("journal.zig");
const asset = @import("asset.zig");
const zcrypto = @import("zcrypto");

pub const AuditReport = struct {
    timestamp: i64,
    total_transactions: u64,
    integrity_valid: bool,
    double_entry_valid: bool,
    hmac_valid: bool,
    balance_discrepancies: std.ArrayList(BalanceDiscrepancy),
    duplicate_transactions: std.ArrayList([]const u8),
    orphaned_transactions: std.ArrayList([]const u8),
    audit_trail_hmac: [32]u8,

    pub fn init(_: std.mem.Allocator) AuditReport {
        return AuditReport{
            .timestamp = std.time.timestamp(),
            .total_transactions = 0,
            .integrity_valid = false,
            .double_entry_valid = false,
            .hmac_valid = false,
            .balance_discrepancies = std.ArrayList(BalanceDiscrepancy){},
            .duplicate_transactions = std.ArrayList([]const u8){},
            .orphaned_transactions = std.ArrayList([]const u8){},
            .audit_trail_hmac = std.mem.zeroes([32]u8),
        };
    }

    pub fn deinit(self: *AuditReport, allocator: std.mem.Allocator) void {
        for (self.balance_discrepancies.items) |*discrepancy| {
            discrepancy.deinit(allocator);
        }
        self.balance_discrepancies.deinit(allocator);

        for (self.duplicate_transactions.items) |tx_id| {
            allocator.free(tx_id);
        }
        self.duplicate_transactions.deinit(allocator);

        for (self.orphaned_transactions.items) |tx_id| {
            allocator.free(tx_id);
        }
        self.orphaned_transactions.deinit(allocator);
    }

    pub fn isValid(self: AuditReport) bool {
        return self.integrity_valid and
            self.double_entry_valid and
            self.hmac_valid and
            self.balance_discrepancies.items.len == 0 and
            self.duplicate_transactions.items.len == 0 and
            self.orphaned_transactions.items.len == 0;
    }

    pub fn toJson(self: AuditReport, allocator: std.mem.Allocator) ![]u8 {
        var json_obj = std.json.ObjectMap.init(allocator);
        defer json_obj.deinit();

        try json_obj.put("timestamp", std.json.Value{ .integer = self.timestamp });
        try json_obj.put("total_transactions", std.json.Value{ .integer = @intCast(self.total_transactions) });
        try json_obj.put("integrity_valid", std.json.Value{ .bool = self.integrity_valid });
        try json_obj.put("double_entry_valid", std.json.Value{ .bool = self.double_entry_valid });
        try json_obj.put("hmac_valid", std.json.Value{ .bool = self.hmac_valid });
        try json_obj.put("is_valid", std.json.Value{ .bool = self.isValid() });

        const hmac_hex = try std.fmt.allocPrint(allocator, "{x}", .{self.audit_trail_hmac});
        defer allocator.free(hmac_hex);
        try json_obj.put("audit_trail_hmac", std.json.Value{ .string = hmac_hex });

        const json_value = std.json.Value{ .object = json_obj };
        var out: std.Io.Writer.Allocating = .init(allocator);
        defer out.deinit();
        try std.json.Stringify.value(json_value, .{}, &out.writer);
        return out.toOwnedSlice();
    }
};

pub const BalanceDiscrepancy = struct {
    account_name: []const u8,
    expected_balance: i64,
    actual_balance: i64,
    difference: i64,

    pub fn init(allocator: std.mem.Allocator, account_name: []const u8, expected: i64, actual: i64) !BalanceDiscrepancy {
        return BalanceDiscrepancy{
            .account_name = try allocator.dupe(u8, account_name),
            .expected_balance = expected,
            .actual_balance = actual,
            .difference = actual - expected,
        };
    }

    pub fn deinit(self: *BalanceDiscrepancy, allocator: std.mem.Allocator) void {
        allocator.free(self.account_name);
    }
};

pub const Auditor = struct {
    allocator: std.mem.Allocator,
    audit_key: [32]u8,

    pub fn init(allocator: std.mem.Allocator) Auditor {
        return Auditor{
            .allocator = allocator,
            .audit_key = zcrypto.rand.generateKey(32),
        };
    }

    pub fn initWithKey(allocator: std.mem.Allocator, key: [32]u8) Auditor {
        return Auditor{
            .allocator = allocator,
            .audit_key = key,
        };
    }

    pub fn auditLedger(self: *Auditor, ledger: *account.Ledger, journal_ref: *journal.Journal) !AuditReport {
        var report = AuditReport.init(self.allocator);
        report.total_transactions = journal_ref.entries.items.len;

        report.integrity_valid = try journal_ref.verifyIntegrity();
        report.double_entry_valid = ledger.verifyDoubleEntry();

        // Generate audit trail HMAC
        report.audit_trail_hmac = try self.generateAuditTrailHMAC(journal_ref);
        report.hmac_valid = try self.verifyAuditTrailHMAC(journal_ref, report.audit_trail_hmac);

        try self.checkForDuplicateTransactions(&report, journal_ref);
        try self.checkForOrphanedTransactions(&report, ledger, journal_ref);
        try self.verifyBalanceConsistency(&report, ledger, journal_ref);

        return report;
    }

    pub fn generateAuditTrailHMAC(self: *Auditor, journal_ref: *journal.Journal) ![32]u8 {
        var hmac_data = std.ArrayList(u8){};
        defer hmac_data.deinit(self.allocator);

        // Create audit trail data by concatenating all transaction data
        for (journal_ref.entries.items) |entry| {
            const tx_json = try entry.transaction.toJson(self.allocator);
            defer self.allocator.free(tx_json);

            try hmac_data.appendSlice(self.allocator, tx_json);
            try hmac_data.append(self.allocator, '|'); // separator
        }

        return zcrypto.auth.hmac.sha256(hmac_data.items, &self.audit_key);
    }

    pub fn verifyAuditTrailHMAC(self: *Auditor, journal_ref: *journal.Journal, expected_hmac: [32]u8) !bool {
        const computed_hmac = try self.generateAuditTrailHMAC(journal_ref);
        return zcrypto.util.constantTimeCompare(&expected_hmac, &computed_hmac);
    }

    pub fn generateTransactionHMAC(self: *Auditor, transaction: tx.Transaction) ![32]u8 {
        const tx_json = try transaction.toJson(self.allocator);
        defer self.allocator.free(tx_json);

        return zcrypto.auth.hmac.sha256(tx_json, &self.audit_key);
    }

    pub fn verifyTransactionHMAC(self: *Auditor, transaction: tx.Transaction, expected_hmac: [32]u8) !bool {
        const computed_hmac = try self.generateTransactionHMAC(transaction);
        return zcrypto.util.constantTimeCompare(&expected_hmac, &computed_hmac);
    }

    pub fn verifyTransactionChain(self: *Auditor, journal_ref: *journal.Journal) !bool {
        if (journal_ref.entries.items.len == 0) return true;

        for (journal_ref.entries.items, 0..) |entry, i| {
            if (i == 0) {
                if (entry.prev_hash != null) return false;
            } else {
                const prev_entry = journal_ref.entries.items[i - 1];
                if (entry.prev_hash == null or !zcrypto.util.constantTimeCompare(&(entry.prev_hash.?), &prev_entry.hash)) {
                    return false;
                }
            }

            if (!(try entry.verify(self.allocator))) return false;
            if (entry.sequence != i) return false;
        }

        return true;
    }

    pub fn recalculateBalances(self: *Auditor, ledger: *account.Ledger, journal_ref: *journal.Journal) !std.HashMap([]const u8, i64, std.hash_map.StringContext, std.hash_map.default_max_load_percentage) {
        var calculated_balances = std.HashMap([]const u8, i64, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(self.allocator);

        var account_iterator = ledger.accounts.iterator();
        while (account_iterator.next()) |entry| {
            const account_name = try self.allocator.dupe(u8, entry.key_ptr.*);
            try calculated_balances.put(account_name, 0);
        }

        for (journal_ref.entries.items) |entry| {
            const transaction = entry.transaction;

            if (calculated_balances.getPtr(transaction.from_account)) |from_balance| {
                from_balance.* -= transaction.amount;
            }

            if (calculated_balances.getPtr(transaction.to_account)) |to_balance| {
                to_balance.* += transaction.amount;
            }
        }

        return calculated_balances;
    }

    fn checkForDuplicateTransactions(self: *Auditor, report: *AuditReport, journal_ref: *journal.Journal) !void {
        var seen_ids = std.HashMap([]const u8, void, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(self.allocator);
        defer {
            var iterator = seen_ids.iterator();
            while (iterator.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            seen_ids.deinit();
        }

        for (journal_ref.entries.items) |entry| {
            const tx_id = entry.transaction.id;
            if (seen_ids.contains(tx_id)) {
                const duplicate_id = try self.allocator.dupe(u8, tx_id);
                try report.duplicate_transactions.append(self.allocator, duplicate_id);
            } else {
                const owned_id = try self.allocator.dupe(u8, tx_id);
                try seen_ids.put(owned_id, {});
            }
        }
    }

    fn checkForOrphanedTransactions(self: *Auditor, report: *AuditReport, ledger: *account.Ledger, journal_ref: *journal.Journal) !void {
        for (journal_ref.entries.items) |entry| {
            const transaction = entry.transaction;

            if (!ledger.accounts.contains(transaction.from_account) or
                !ledger.accounts.contains(transaction.to_account))
            {
                const orphaned_id = try self.allocator.dupe(u8, transaction.id);
                try report.orphaned_transactions.append(self.allocator, orphaned_id);
            }
        }
    }

    fn verifyBalanceConsistency(self: *Auditor, report: *AuditReport, ledger: *account.Ledger, journal_ref: *journal.Journal) !void {
        var calculated_balances = try self.recalculateBalances(ledger, journal_ref);
        defer {
            var iterator = calculated_balances.iterator();
            while (iterator.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            calculated_balances.deinit();
        }

        var account_iterator = ledger.accounts.iterator();
        while (account_iterator.next()) |entry| {
            const account_name = entry.key_ptr.*;
            const actual_balance = entry.value_ptr.balance;

            if (calculated_balances.get(account_name)) |expected_balance| {
                if (actual_balance != expected_balance) {
                    const discrepancy = try BalanceDiscrepancy.init(self.allocator, account_name, expected_balance, actual_balance);
                    try report.balance_discrepancies.append(self.allocator, discrepancy);
                }
            }
        }
    }
};

pub const AuditProofChain = struct {
    entries: std.ArrayList(AuditEntry),
    chain_hash: [32]u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AuditProofChain {
        return AuditProofChain{
            .entries = std.ArrayList(AuditEntry){},
            .chain_hash = std.mem.zeroes([32]u8),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AuditProofChain) void {
        for (self.entries.items) |*entry| {
            entry.deinit(self.allocator);
        }
        self.entries.deinit(self.allocator);
    }

    pub fn addEntry(self: *AuditProofChain, event_type: AuditEventType, data: []const u8) !void {
        const entry = try AuditEntry.init(self.allocator, event_type, data, self.chain_hash);
        self.chain_hash = entry.hash;
        try self.entries.append(self.allocator, entry);
    }

    pub fn verifyChainIntegrity(self: *AuditProofChain) bool {
        var previous_hash = std.mem.zeroes([32]u8);

        for (self.entries.items) |entry| {
            if (!std.mem.eql(u8, &entry.previous_hash, &previous_hash)) {
                return false;
            }
            previous_hash = entry.hash;
        }

        return std.mem.eql(u8, &self.chain_hash, &previous_hash);
    }
};

pub const AuditEventType = enum {
    transaction_processed,
    transaction_rolled_back,
    account_created,
    asset_registered,
    balance_updated,
    system_checkpoint,
};

pub const AuditEntry = struct {
    timestamp: i64,
    event_type: AuditEventType,
    data: []const u8,
    previous_hash: [32]u8,
    hash: [32]u8,

    pub fn init(allocator: std.mem.Allocator, event_type: AuditEventType, data: []const u8, previous_hash: [32]u8) !AuditEntry {
        const timestamp = std.time.timestamp();
        const owned_data = try allocator.dupe(u8, data);

        // Calculate hash of this entry
        var hash_input = std.ArrayList(u8){};
        defer hash_input.deinit(allocator);

        try hash_input.appendSlice(std.mem.asBytes(&timestamp));
        try hash_input.appendSlice(std.mem.asBytes(&event_type));
        try hash_input.appendSlice(owned_data);
        try hash_input.appendSlice(&previous_hash);

        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(hash_input.items, &hash, .{});

        return AuditEntry{
            .timestamp = timestamp,
            .event_type = event_type,
            .data = owned_data,
            .previous_hash = previous_hash,
            .hash = hash,
        };
    }

    pub fn deinit(self: *AuditEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    pub fn verify(self: *AuditEntry, allocator: std.mem.Allocator) bool {
        // Recalculate hash and verify
        var hash_input = std.ArrayList(u8){};
        defer hash_input.deinit(allocator);

        hash_input.appendSlice(allocator, std.mem.asBytes(&self.timestamp)) catch return false;
        hash_input.appendSlice(allocator, std.mem.asBytes(&self.event_type)) catch return false;
        hash_input.appendSlice(allocator, self.data) catch return false;
        hash_input.appendSlice(allocator, &self.previous_hash) catch return false;

        var calculated_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(hash_input.items, &calculated_hash, .{});

        return std.mem.eql(u8, &self.hash, &calculated_hash);
    }
};

test "audit basic ledger operations" {
    const allocator = std.testing.allocator;

    var ledger = account.Ledger.init(allocator);
    defer ledger.deinit();

    var journal_ref = journal.Journal.init(allocator, null);
    defer journal_ref.deinit();

    // Register USD asset
    var usd_asset = try asset.Asset.init(allocator, "USD", .native, "USD", "US Dollar", 2);
    defer usd_asset.deinit(allocator);
    try ledger.asset_registry.registerAsset(usd_asset);

    try ledger.createAccount("alice", .asset, "USD");
    try ledger.createAccount("bob", .asset, "USD");

    var transaction = try tx.Transaction.init(allocator, 50000, "USD", "alice", "bob", "Test payment");
    defer transaction.deinit(allocator);
    try journal_ref.append(transaction);
    try ledger.processTransaction(transaction);

    var auditor = Auditor.init(allocator);
    var report = try auditor.auditLedger(&ledger, &journal_ref);
    defer report.deinit(allocator);

    try std.testing.expect(report.integrity_valid);
    try std.testing.expect(report.double_entry_valid);
    try std.testing.expectEqual(@as(usize, 1), report.total_transactions);
}

test "audit detects balance discrepancies" {
    const allocator = std.testing.allocator;

    var ledger = account.Ledger.init(allocator);
    defer ledger.deinit();

    var journal_ref = journal.Journal.init(allocator, null);
    defer journal_ref.deinit();

    // Register USD asset
    var usd_asset = try asset.Asset.init(allocator, "USD", .native, "USD", "US Dollar", 2);
    defer usd_asset.deinit(allocator);
    try ledger.asset_registry.registerAsset(usd_asset);

    try ledger.createAccount("alice", .asset, "USD");
    try ledger.createAccount("bob", .asset, "USD");

    var transaction = try tx.Transaction.init(allocator, 50000, "USD", "alice", "bob", "Test payment");
    defer transaction.deinit(allocator);
    try journal_ref.append(transaction);

    const alice = ledger.getAccount("alice").?;
    alice.balance = 25000;

    var auditor = Auditor.init(allocator);
    var report = try auditor.auditLedger(&ledger, &journal_ref);
    defer report.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), report.balance_discrepancies.items.len);
    try std.testing.expect(!report.isValid());
}

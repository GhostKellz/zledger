const std = @import("std");
const crypto = std.crypto;
const zcrypto = @import("zcrypto");

pub const Transaction = struct {
    id: []const u8,
    timestamp: i64,
    amount: i64,
    currency: []const u8,
    from_account: []const u8,
    to_account: []const u8,
    memo: ?[]const u8,
    signature: ?[64]u8,
    integrity_hmac: ?[32]u8,
    nonce: [12]u8,
    depends_on: ?[]const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        amount: i64,
        currency: []const u8,
        from_account: []const u8,
        to_account: []const u8,
        memo: ?[]const u8,
    ) !Transaction {
        return initWithDependency(allocator, amount, currency, from_account, to_account, memo, null);
    }

    pub fn initWithDependency(
        allocator: std.mem.Allocator,
        amount: i64,
        currency: []const u8,
        from_account: []const u8,
        to_account: []const u8,
        memo: ?[]const u8,
        depends_on: ?[]const u8,
    ) !Transaction {
        const timestamp = std.time.timestamp();
        const id = try generateTxId(allocator, timestamp, from_account, to_account, amount);

        var nonce: [12]u8 = undefined;
        zcrypto.rand.fillBytes(&nonce);

        return Transaction{
            .id = id,
            .timestamp = timestamp,
            .amount = amount,
            .currency = try allocator.dupe(u8, currency),
            .from_account = try allocator.dupe(u8, from_account),
            .to_account = try allocator.dupe(u8, to_account),
            .memo = if (memo) |m| try allocator.dupe(u8, m) else null,
            .signature = null,
            .integrity_hmac = null,
            .nonce = nonce,
            .depends_on = if (depends_on) |dep| try allocator.dupe(u8, dep) else null,
        };
    }

    pub fn deinit(self: *Transaction, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.currency);
        allocator.free(self.from_account);
        allocator.free(self.to_account);
        if (self.memo) |memo| {
            allocator.free(memo);
        }
        if (self.depends_on) |dep| {
            allocator.free(dep);
        }
    }

    pub fn clone(self: Transaction, allocator: std.mem.Allocator) !Transaction {
        return Transaction{
            .id = try allocator.dupe(u8, self.id),
            .timestamp = self.timestamp,
            .amount = self.amount,
            .currency = try allocator.dupe(u8, self.currency),
            .from_account = try allocator.dupe(u8, self.from_account),
            .to_account = try allocator.dupe(u8, self.to_account),
            .memo = if (self.memo) |m| try allocator.dupe(u8, m) else null,
            .signature = self.signature,
            .integrity_hmac = self.integrity_hmac,
            .nonce = self.nonce,
            .depends_on = if (self.depends_on) |dep| try allocator.dupe(u8, dep) else null,
        };
    }

    pub fn toJson(self: Transaction, allocator: std.mem.Allocator) ![]u8 {
        var json_obj = std.json.ObjectMap.init(allocator);
        defer json_obj.deinit();

        try json_obj.put("id", std.json.Value{ .string = self.id });
        try json_obj.put("timestamp", std.json.Value{ .integer = self.timestamp });
        try json_obj.put("amount", std.json.Value{ .integer = self.amount });
        try json_obj.put("currency", std.json.Value{ .string = self.currency });
        try json_obj.put("from_account", std.json.Value{ .string = self.from_account });
        try json_obj.put("to_account", std.json.Value{ .string = self.to_account });

        if (self.memo) |memo| {
            try json_obj.put("memo", std.json.Value{ .string = memo });
        } else {
            try json_obj.put("memo", std.json.Value.null);
        }

        // Add cryptographic fields
        const nonce_hex = try std.fmt.allocPrint(allocator, "{x}", .{self.nonce});
        errdefer allocator.free(nonce_hex);
        try json_obj.put("nonce", std.json.Value{ .string = nonce_hex });

        var sig_hex: ?[]u8 = null;
        errdefer if (sig_hex) |s| allocator.free(s);
        if (self.signature) |sig| {
            sig_hex = try std.fmt.allocPrint(allocator, "{x}", .{sig});
            try json_obj.put("signature", std.json.Value{ .string = sig_hex.? });
        } else {
            try json_obj.put("signature", std.json.Value.null);
        }

        var hmac_hex: ?[]u8 = null;
        errdefer if (hmac_hex) |h| allocator.free(h);
        if (self.integrity_hmac) |hmac| {
            hmac_hex = try std.fmt.allocPrint(allocator, "{x}", .{hmac});
            try json_obj.put("integrity_hmac", std.json.Value{ .string = hmac_hex.? });
        } else {
            try json_obj.put("integrity_hmac", std.json.Value.null);
        }

        if (self.depends_on) |dep| {
            try json_obj.put("depends_on", std.json.Value{ .string = dep });
        } else {
            try json_obj.put("depends_on", std.json.Value.null);
        }

        const json_value = std.json.Value{ .object = json_obj };
        var out: std.Io.Writer.Allocating = .init(allocator);
        defer out.deinit();
        try std.json.Stringify.value(json_value, .{}, &out.writer);
        const result = out.toOwnedSlice();
        
        // Now we can safely free the hex strings
        allocator.free(nonce_hex);
        if (sig_hex) |s| allocator.free(s);
        if (hmac_hex) |h| allocator.free(h);
        
        return result;
    }

    pub fn fromJson(allocator: std.mem.Allocator, json_str: []const u8) !Transaction {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
        defer parsed.deinit();

        const obj = parsed.value.object;

        const id = try allocator.dupe(u8, obj.get("id").?.string);
        const timestamp = obj.get("timestamp").?.integer;
        const amount = obj.get("amount").?.integer;
        const currency = try allocator.dupe(u8, obj.get("currency").?.string);
        const from_account = try allocator.dupe(u8, obj.get("from_account").?.string);
        const to_account = try allocator.dupe(u8, obj.get("to_account").?.string);

        var memo: ?[]u8 = null;
        if (obj.get("memo")) |memo_value| {
            if (memo_value != .null) {
                memo = try allocator.dupe(u8, memo_value.string);
            }
        }

        var depends_on: ?[]u8 = null;
        if (obj.get("depends_on")) |dep_value| {
            if (dep_value != .null) {
                depends_on = try allocator.dupe(u8, dep_value.string);
            }
        }

        return Transaction{
            .id = id,
            .timestamp = timestamp,
            .amount = amount,
            .currency = currency,
            .from_account = from_account,
            .to_account = to_account,
            .memo = memo,
            .signature = null,
            .integrity_hmac = null,
            .nonce = [_]u8{0} ** 12,
            .depends_on = depends_on,
        };
    }

    pub fn getHash(self: Transaction, allocator: std.mem.Allocator) ![32]u8 {
        const tx_data = try self.toJson(allocator);
        defer allocator.free(tx_data);

        var hash: [32]u8 = undefined;
        crypto.hash.sha2.Sha256.hash(tx_data, &hash, .{});
        return hash;
    }

    pub fn signTransaction(self: *Transaction, allocator: std.mem.Allocator) !void {
        const tx_data = try self.getTransactionDataForSigning(allocator);
        defer allocator.free(tx_data);

        const keypair = zcrypto.asym.ed25519.generate();
        const signature = keypair.sign(tx_data);
        self.signature = signature;
    }

    pub fn verifySignature(self: Transaction, allocator: std.mem.Allocator, public_key: [32]u8) !bool {
        if (self.signature == null) return false;

        const tx_data = try self.getTransactionDataForSigning(allocator);
        defer allocator.free(tx_data);

        const keypair = zcrypto.asym.ed25519.KeyPair{ .public_key = public_key, .private_key = undefined };
        return keypair.verify(tx_data, self.signature.?);
    }

    pub fn generateIntegrityHMAC(self: *Transaction, allocator: std.mem.Allocator, hmac_key: [32]u8) !void {
        const tx_data = try self.getTransactionDataForSigning(allocator);
        defer allocator.free(tx_data);

        self.integrity_hmac = zcrypto.auth.hmac.sha256(tx_data, &hmac_key);
    }

    pub fn verifyIntegrityHMAC(self: Transaction, allocator: std.mem.Allocator, hmac_key: [32]u8) !bool {
        if (self.integrity_hmac == null) return false;

        const tx_data = try self.getTransactionDataForSigning(allocator);
        defer allocator.free(tx_data);

        const computed_hmac = zcrypto.auth.hmac.sha256(tx_data, &hmac_key);
        return zcrypto.util.constantTimeCompare(&self.integrity_hmac.?, &computed_hmac);
    }

    pub fn hasDependency(self: Transaction) bool {
        return self.depends_on != null;
    }

    pub fn getDependency(self: Transaction) ?[]const u8 {
        return self.depends_on;
    }

    pub fn validateDependencies(self: Transaction, processed_transactions: *const std.HashMap([]const u8, void, std.hash_map.StringContext, std.hash_map.default_max_load_percentage)) !void {
        if (self.depends_on) |dep_id| {
            if (!processed_transactions.contains(dep_id)) {
                return error.DependencyNotFound;
            }
        }
    }

    pub fn getTransactionDataForSigning(self: Transaction, allocator: std.mem.Allocator) ![]u8 {
        return try std.fmt.allocPrint(allocator, "{d}|{d}|{s}|{s}|{s}|{s}|{x}", .{ self.timestamp, self.amount, self.currency, self.from_account, self.to_account, self.memo orelse "", self.nonce });
    }
};

fn generateTxId(allocator: std.mem.Allocator, timestamp: i64, from: []const u8, to: []const u8, amount: i64) ![]u8 {
    const id_data = try std.fmt.allocPrint(allocator, "{d}-{s}-{s}-{d}", .{ timestamp, from, to, amount });
    defer allocator.free(id_data);

    var hash: [32]u8 = undefined;
    crypto.hash.sha2.Sha256.hash(id_data, &hash, .{});

    return try std.fmt.allocPrint(allocator, "{x}", .{hash[0..8]});
}

test "transaction creation and serialization" {
    const allocator = std.testing.allocator;

    var tx = try Transaction.init(allocator, 100000, "USD", "alice", "bob", "Test payment");
    defer tx.deinit(allocator);

    const json = try tx.toJson(allocator);
    defer allocator.free(json);

    var tx2 = try Transaction.fromJson(allocator, json);
    defer tx2.deinit(allocator);

    try std.testing.expectEqualStrings(tx.currency, tx2.currency);
    try std.testing.expectEqual(tx.amount, tx2.amount);
    try std.testing.expectEqualStrings(tx.from_account, tx2.from_account);
    try std.testing.expectEqualStrings(tx.to_account, tx2.to_account);
}

test "transaction dependency tracking" {
    const account = @import("account.zig");
    const asset = @import("asset.zig");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ledger = account.Ledger.init(allocator);
    defer ledger.deinit();

    // Register USD asset
    var usd_asset = try asset.Asset.init(allocator, "USD", .native, "USD", "US Dollar", 2);
    defer usd_asset.deinit(allocator);
    try ledger.asset_registry.registerAsset(usd_asset);

    // Create test accounts
    try ledger.createAccount("alice", .asset, "USD");
    try ledger.createAccount("bob", .asset, "USD");

    // Create first transaction (no dependency)
    var tx1 = try Transaction.init(allocator, 100, "USD", "alice", "bob", "First transaction");
    defer tx1.deinit(allocator);

    // Create second transaction that depends on first
    var tx2 = try Transaction.initWithDependency(allocator, 50, "USD", "bob", "alice", "Second transaction", tx1.id);
    defer tx2.deinit(allocator);

    // Process first transaction should succeed
    try ledger.processTransaction(tx1);
    try std.testing.expect(ledger.isTransactionProcessed(tx1.id));

    // Process second transaction should succeed (dependency satisfied)
    try ledger.processTransaction(tx2);
    try std.testing.expect(ledger.isTransactionProcessed(tx2.id));
}

test "transaction dependency validation fails" {
    const account = @import("account.zig");
    const asset = @import("asset.zig");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ledger = account.Ledger.init(allocator);
    defer ledger.deinit();

    // Register USD asset
    var usd_asset = try asset.Asset.init(allocator, "USD", .native, "USD", "US Dollar", 2);
    defer usd_asset.deinit(allocator);
    try ledger.asset_registry.registerAsset(usd_asset);

    // Create test accounts
    try ledger.createAccount("alice", .asset, "USD");
    try ledger.createAccount("bob", .asset, "USD");

    // Create transaction with dependency that doesn't exist
    var tx = try Transaction.initWithDependency(allocator, 100, "USD", "alice", "bob", "Dependent transaction", "nonexistent_tx_id");
    defer tx.deinit(allocator);

    // Should fail with DependencyNotFound
    try std.testing.expectError(error.DependencyNotFound, ledger.processTransaction(tx));
}

test "transaction dependency JSON serialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create transaction with dependency
    var tx = try Transaction.initWithDependency(allocator, 100, "USD", "alice", "bob", "Test transaction", "parent_tx_id");
    defer tx.deinit(allocator);

    // Test JSON serialization includes dependency
    const json = try tx.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "depends_on") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "parent_tx_id") != null);

    // Test round-trip serialization
    var tx_restored = try Transaction.fromJson(allocator, json);
    defer tx_restored.deinit(allocator);

    try std.testing.expect(tx_restored.depends_on != null);
    try std.testing.expectEqualStrings("parent_tx_id", tx_restored.depends_on.?);
}

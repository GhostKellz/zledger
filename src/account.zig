const std = @import("std");
const tx = @import("tx.zig");
const asset = @import("asset.zig");

pub const AccountType = enum {
    asset,
    liability,
    equity,
    revenue,
    expense,
};

pub const Account = struct {
    name: []const u8,
    account_type: AccountType,
    balance: i64,
    currency: []const u8,
    created_at: i64,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, account_type: AccountType, currency: []const u8) !Account {
        return Account{
            .name = try allocator.dupe(u8, name),
            .account_type = account_type,
            .balance = 0,
            .currency = try allocator.dupe(u8, currency),
            .created_at = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *Account, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.currency);
    }

    pub fn clone(self: Account, allocator: std.mem.Allocator) !Account {
        return Account{
            .name = try allocator.dupe(u8, self.name),
            .account_type = self.account_type,
            .balance = self.balance,
            .currency = try allocator.dupe(u8, self.currency),
            .created_at = self.created_at,
        };
    }

    pub fn credit(self: *Account, amount: i64) void {
        switch (self.account_type) {
            .liability, .equity, .revenue => self.balance += amount,
            .asset, .expense => self.balance -= amount,
        }
    }

    pub fn debit(self: *Account, amount: i64) void {
        switch (self.account_type) {
            .asset, .expense => self.balance += amount,
            .liability, .equity, .revenue => self.balance -= amount,
        }
    }
};

pub const Ledger = struct {
    accounts: std.HashMap([]const u8, Account, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    processed_transactions: std.HashMap([]const u8, void, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    transaction_snapshots: std.HashMap([]const u8, TransactionSnapshot, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    asset_registry: asset.AssetRegistry,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Ledger {
        return Ledger{
            .accounts = std.HashMap([]const u8, Account, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .processed_transactions = std.HashMap([]const u8, void, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .transaction_snapshots = std.HashMap([]const u8, TransactionSnapshot, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .asset_registry = asset.AssetRegistry.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Ledger) void {
        var iterator = self.accounts.iterator();
        while (iterator.next()) |entry| {
            var account = entry.value_ptr;
            account.deinit(self.allocator);
        }
        self.accounts.deinit();

        var tx_iterator = self.processed_transactions.iterator();
        while (tx_iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.processed_transactions.deinit();
    }

    pub fn createAccount(self: *Ledger, name: []const u8, account_type: AccountType, currency: []const u8) !void {
        if (self.accounts.contains(name)) {
            return error.AccountExists;
        }

        var account = try Account.init(self.allocator, name, account_type, currency);
        defer account.deinit(self.allocator);
        const owned_name = try self.allocator.dupe(u8, name);
        const cloned_account = try account.clone(self.allocator);
        try self.accounts.put(owned_name, cloned_account);
    }

    pub fn getAccount(self: *Ledger, name: []const u8) ?*Account {
        return self.accounts.getPtr(name);
    }

    pub fn getBalance(self: *Ledger, account_name: []const u8) ?i64 {
        if (self.getAccount(account_name)) |account| {
            return account.balance;
        }
        return null;
    }

    pub fn processTransaction(self: *Ledger, transaction: tx.Transaction) !void {
        // Validate transaction dependencies first
        try transaction.validateDependencies(&self.processed_transactions);

        // Validate asset rules
        try self.asset_registry.validateAssetTransaction(transaction.currency, transaction.amount);

        var from_account = self.getAccount(transaction.from_account) orelse return error.FromAccountNotFound;
        var to_account = self.getAccount(transaction.to_account) orelse return error.ToAccountNotFound;

        if (!std.mem.eql(u8, from_account.currency, transaction.currency) or
            !std.mem.eql(u8, to_account.currency, transaction.currency))
        {
            return error.CurrencyMismatch;
        }

        from_account.credit(transaction.amount);
        to_account.debit(transaction.amount);

        // Mark transaction as processed
        const tx_id = try self.allocator.dupe(u8, transaction.id);
        try self.processed_transactions.put(tx_id, {});
    }

    pub fn processTransactionWithRollback(self: *Ledger, transaction: tx.Transaction) !void {
        // Create snapshot before processing
        const from_account = self.getAccount(transaction.from_account) orelse return error.FromAccountNotFound;
        const to_account = self.getAccount(transaction.to_account) orelse return error.ToAccountNotFound;

        const affected_accounts = [_]*const Account{ from_account, to_account };
        const snapshot = try TransactionSnapshot.init(self.allocator, transaction.id, @constCast(affected_accounts[0..]));

        // Store snapshot
        try self.transaction_snapshots.put(try self.allocator.dupe(u8, transaction.id), snapshot);

        // Process transaction normally
        self.processTransaction(transaction) catch |err| {
            // Rollback on failure
            try self.rollbackTransaction(transaction.id);
            return err;
        };
    }

    pub fn rollbackTransaction(self: *Ledger, transaction_id: []const u8) !void {
        const snapshot = self.transaction_snapshots.get(transaction_id) orelse return error.SnapshotNotFound;

        // Restore account balances
        for (snapshot.account_snapshots) |account_snapshot| {
            if (self.getAccount(account_snapshot.name)) |account| {
                account.balance = account_snapshot.balance;
            }
        }

        // Remove from processed transactions
        if (self.processed_transactions.getPtr(transaction_id)) |_| {
            _ = self.processed_transactions.remove(transaction_id);
        }

        std.log.info("Transaction {s} rolled back successfully", .{transaction_id});
    }

    pub fn commitTransaction(self: *Ledger, transaction_id: []const u8) !void {
        // Remove snapshot as transaction is now committed
        if (self.transaction_snapshots.getPtr(transaction_id)) |snapshot| {
            var snapshot_mut = snapshot;
            snapshot_mut.deinit();
            _ = self.transaction_snapshots.remove(transaction_id);
        }
    }

    pub fn isTransactionProcessed(self: *const Ledger, transaction_id: []const u8) bool {
        return self.processed_transactions.contains(transaction_id);
    }

    pub fn verifyDoubleEntry(self: *Ledger) bool {
        var total_assets: i64 = 0;
        var total_liabilities: i64 = 0;
        var total_equity: i64 = 0;
        var total_revenue: i64 = 0;
        var total_expenses: i64 = 0;

        var iterator = self.accounts.iterator();
        while (iterator.next()) |entry| {
            const account = entry.value_ptr;
            switch (account.account_type) {
                .asset => total_assets += account.balance,
                .liability => total_liabilities += account.balance,
                .equity => total_equity += account.balance,
                .revenue => total_revenue += account.balance,
                .expense => total_expenses += account.balance,
            }
        }

        return total_assets == total_liabilities + total_equity + total_revenue - total_expenses;
    }

    pub fn getTrialBalance(self: *Ledger, allocator: std.mem.Allocator) !std.ArrayList(TrialBalanceEntry) {
        var trial_balance = std.ArrayList(TrialBalanceEntry){};

        var iterator = self.accounts.iterator();
        while (iterator.next()) |entry| {
            const account = entry.value_ptr;
            try trial_balance.append(allocator, TrialBalanceEntry{
                .account_name = try allocator.dupe(u8, account.name),
                .account_type = account.account_type,
                .balance = account.balance,
                .currency = try allocator.dupe(u8, account.currency),
            });
        }

        return trial_balance;
    }
};

pub const TrialBalanceEntry = struct {
    account_name: []const u8,
    account_type: AccountType,
    balance: i64,
    currency: []const u8,

    pub fn deinit(self: *TrialBalanceEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.account_name);
        allocator.free(self.currency);
    }
};

pub const AccountSnapshot = struct {
    name: []const u8,
    balance: i64,

    pub fn init(allocator: std.mem.Allocator, account: *const Account) !AccountSnapshot {
        return AccountSnapshot{
            .name = try allocator.dupe(u8, account.name),
            .balance = account.balance,
        };
    }

    pub fn deinit(self: *AccountSnapshot, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

pub const TransactionSnapshot = struct {
    transaction_id: []const u8,
    account_snapshots: []AccountSnapshot,
    timestamp: i64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, transaction_id: []const u8, affected_accounts: []*const Account) !TransactionSnapshot {
        var snapshots = try allocator.alloc(AccountSnapshot, affected_accounts.len);
        for (affected_accounts, 0..) |account, i| {
            snapshots[i] = try AccountSnapshot.init(allocator, account);
        }

        return TransactionSnapshot{
            .transaction_id = try allocator.dupe(u8, transaction_id),
            .account_snapshots = snapshots,
            .timestamp = std.time.timestamp(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TransactionSnapshot) void {
        for (self.account_snapshots) |*snapshot| {
            snapshot.deinit(self.allocator);
        }
        self.allocator.free(self.account_snapshots);
        self.allocator.free(self.transaction_id);
    }
};

test "account creation and balance operations" {
    const allocator = std.testing.allocator;

    var ledger = Ledger.init(allocator);
    defer ledger.deinit();

    try ledger.createAccount("cash", .asset, "USD");
    try ledger.createAccount("accounts_payable", .liability, "USD");

    const cash_account = ledger.getAccount("cash").?;
    cash_account.debit(10000);

    const ap_account = ledger.getAccount("accounts_payable").?;
    ap_account.credit(10000);

    try std.testing.expectEqual(@as(i64, 10000), cash_account.balance);
    try std.testing.expectEqual(@as(i64, 10000), ap_account.balance);
    try std.testing.expect(ledger.verifyDoubleEntry());
}

test "transaction processing" {
    const allocator = std.testing.allocator;

    var ledger = Ledger.init(allocator);
    defer ledger.deinit();

    // Register USD asset
    var usd_asset = try asset.Asset.init(allocator, "USD", .native, "USD", "US Dollar", 2);
    defer usd_asset.deinit(allocator);
    try ledger.asset_registry.registerAsset(usd_asset);

    try ledger.createAccount("alice", .asset, "USD");
    try ledger.createAccount("bob", .asset, "USD");

    const alice = ledger.getAccount("alice").?;
    alice.debit(100000);

    var transaction = try tx.Transaction.init(allocator, 50000, "USD", "alice", "bob", "Payment to Bob");
    defer transaction.deinit(allocator);

    try ledger.processTransaction(transaction);

    try std.testing.expectEqual(@as(i64, 50000), alice.balance);
    try std.testing.expectEqual(@as(i64, 50000), ledger.getAccount("bob").?.balance);
}

test "transaction processing with rollback" {
    const allocator = std.testing.allocator;

    var ledger = Ledger.init(allocator);
    defer ledger.deinit();

    // Register USD asset
    var usd_asset = try asset.Asset.init(allocator, "USD", .native, "USD", "US Dollar", 2);
    defer usd_asset.deinit(allocator);
    try ledger.asset_registry.registerAsset(usd_asset);

    try ledger.createAccount("charlie", .asset, "USD");
    try ledger.createAccount("dave", .asset, "USD");

    const charlie = ledger.getAccount("charlie").?;
    charlie.debit(100000);

    var transaction = try tx.Transaction.init(allocator, 50000, "USD", "charlie", "dave", "Payment to Dave");
    defer transaction.deinit(allocator);

    // Process transaction with rollback
    try ledger.processTransactionWithRollback(transaction);

    try std.testing.expectEqual(@as(i64, 50000), charlie.balance);
    try std.testing.expectEqual(@as(i64, 50000), ledger.getAccount("dave").?.balance);

    // Rollback the transaction
    try ledger.rollbackTransaction(transaction.id);

    try std.testing.expectEqual(@as(i64, 100000), charlie.balance);
    try std.testing.expectEqual(@as(i64, 0), ledger.getAccount("dave").?.balance);
}

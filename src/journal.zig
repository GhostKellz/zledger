const std = @import("std");
const tx = @import("tx.zig");
const crypto = std.crypto;
const crypto_storage = @import("crypto_storage.zig");
const zcrypto = @import("zcrypto");

pub const JournalEntry = struct {
    transaction: tx.Transaction,
    prev_hash: ?[32]u8,
    hash: [32]u8,
    sequence: u64,

    pub fn init(allocator: std.mem.Allocator, transaction: tx.Transaction, prev_hash: ?[32]u8, sequence: u64) !JournalEntry {
        const hash = try calculateEntryHash(allocator, transaction, prev_hash, sequence);
        
        return JournalEntry{
            .transaction = transaction,
            .prev_hash = prev_hash,
            .hash = hash,
            .sequence = sequence,
        };
    }

    pub fn verify(self: JournalEntry, allocator: std.mem.Allocator) !bool {
        const expected_hash = try calculateEntryHash(allocator, self.transaction, self.prev_hash, self.sequence);
        return zcrypto.util.constantTimeCompare(&self.hash, &expected_hash);
    }
};

pub const Journal = struct {
    entries: std.ArrayList(JournalEntry),
    allocator: std.mem.Allocator,
    file_path: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, file_path: ?[]const u8) Journal {
        return Journal{
            .entries = .{},
            .allocator = allocator,
            .file_path = if (file_path) |path| allocator.dupe(u8, path) catch null else null,
        };
    }

    pub fn deinit(self: *Journal) void {
        for (self.entries.items) |*entry| {
            entry.transaction.deinit(self.allocator);
        }
        self.entries.deinit(self.allocator);
        if (self.file_path) |path| {
            self.allocator.free(path);
        }
    }

    pub fn append(self: *Journal, transaction: tx.Transaction) !void {
        const prev_hash = if (self.entries.items.len > 0) 
            self.entries.items[self.entries.items.len - 1].hash 
        else 
            null;
        
        const sequence = self.entries.items.len;
        const cloned_transaction = try transaction.clone(self.allocator);
        const entry = try JournalEntry.init(self.allocator, cloned_transaction, prev_hash, sequence);
        
        try self.entries.append(self.allocator, entry);
        
        if (self.file_path) |path| {
            try self.persistEntry(entry, path);
        }
    }

    pub fn getEntry(self: *Journal, sequence: u64) ?JournalEntry {
        if (sequence >= self.entries.items.len) return null;
        return self.entries.items[sequence];
    }

    pub fn getTransactionById(self: *Journal, id: []const u8) ?tx.Transaction {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.transaction.id, id)) {
                return entry.transaction;
            }
        }
        return null;
    }

    pub fn getTransactionsByAccount(self: *Journal, allocator: std.mem.Allocator, account: []const u8) !std.ArrayList(tx.Transaction) {
        var transactions = std.ArrayList(tx.Transaction){};
        
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.transaction.from_account, account) or 
                std.mem.eql(u8, entry.transaction.to_account, account)) {
                try transactions.append(allocator, entry.transaction);
            }
        }
        
        return transactions;
    }

    pub fn verifyIntegrity(self: *Journal) !bool {
        if (self.entries.items.len == 0) return true;
        
        for (self.entries.items, 0..) |entry, i| {
            if (!(try entry.verify(self.allocator))) {
                return false;
            }
            
            if (i > 0) {
                const prev_entry = self.entries.items[i - 1];
                if (entry.prev_hash == null or !zcrypto.util.constantTimeCompare(&(entry.prev_hash.?), &prev_entry.hash)) {
                    return false;
                }
            } else {
                if (entry.prev_hash != null) {
                    return false;
                }
            }
            
            if (entry.sequence != i) {
                return false;
            }
        }
        
        return true;
    }

    pub fn loadFromFile(self: *Journal, file_path: []const u8) !void {
        const content = std.fs.cwd().readFileAlloc(file_path, self.allocator, @as(std.Io.Limit, @enumFromInt(std.math.maxInt(usize)))) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        defer self.allocator.free(content);

        var lines = std.mem.splitSequence(u8, content, "\n");
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            
            const transaction = try tx.Transaction.fromJson(self.allocator, line);
            try self.append(transaction);
        }
    }

    pub fn saveToFile(self: *Journal, file_path: []const u8) !void {
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();

        for (self.entries.items) |entry| {
            const json = try entry.transaction.toJson(self.allocator);
            defer self.allocator.free(json);
            
            try file.writeAll(json);
            try file.writeAll("\n");
        }
    }

    fn persistEntry(self: *Journal, entry: JournalEntry, file_path: []const u8) !void {
        const file = std.fs.cwd().openFile(file_path, .{ .mode = .write_only }) catch |err| switch (err) {
            error.FileNotFound => try std.fs.cwd().createFile(file_path, .{}),
            else => return err,
        };
        defer file.close();

        try file.seekFromEnd(0);
        const json = try entry.transaction.toJson(self.allocator);
        defer self.allocator.free(json);
        
        try file.writeAll(json);
        try file.writeAll("\n");
    }

    pub fn saveToEncryptedFile(self: *Journal, file_path: []const u8, password: []const u8) !void {
        var secure_file = try crypto_storage.SecureFile.init(self.allocator, file_path, password);
        defer secure_file.deinit();

        var journal_data = std.ArrayList(u8){};
        defer journal_data.deinit(self.allocator);

        for (self.entries.items) |entry| {
            const json = try entry.transaction.toJson(self.allocator);
            defer self.allocator.free(json);
            
            try journal_data.appendSlice(self.allocator, json);
            try journal_data.append(self.allocator, '\n');
        }

        try secure_file.save(journal_data.items);
    }

    pub fn loadFromEncryptedFile(self: *Journal, file_path: []const u8, password: []const u8) !void {
        var secure_file = try crypto_storage.SecureFile.init(self.allocator, file_path, password);
        defer secure_file.deinit();

        const content = try secure_file.load();
        defer self.allocator.free(content);

        var lines = std.mem.splitSequence(u8, content, "\n");
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            
            const transaction = try tx.Transaction.fromJson(self.allocator, line);
            try self.append(transaction);
        }
    }
};

fn calculateEntryHash(allocator: std.mem.Allocator, transaction: tx.Transaction, prev_hash: ?[32]u8, sequence: u64) ![32]u8 {
    const tx_hash = try transaction.getHash(allocator);
    
    var hash_data = std.ArrayList(u8){};
    defer hash_data.deinit(allocator);
    
    try hash_data.appendSlice(allocator, &tx_hash);
    try hash_data.appendSlice(allocator, std.mem.asBytes(&sequence));
    
    if (prev_hash) |prev| {
        try hash_data.appendSlice(allocator, &prev);
    }
    
    var hash: [32]u8 = undefined;
    crypto.hash.sha2.Sha256.hash(hash_data.items, &hash, .{});
    return hash;
}

test "journal operations" {
    const allocator = std.testing.allocator;
    
    var journal = Journal.init(allocator, null);
    defer journal.deinit();

    const tx1 = try tx.Transaction.init(allocator, 100000, "USD", "alice", "bob", "Payment 1");
    try journal.append(tx1);

    const tx2 = try tx.Transaction.init(allocator, 50000, "USD", "bob", "charlie", "Payment 2");
    try journal.append(tx2);

    try std.testing.expectEqual(@as(usize, 2), journal.entries.items.len);
    try std.testing.expect(try journal.verifyIntegrity());
    
    const first_entry = journal.getEntry(0).?;
    try std.testing.expectEqual(@as(u64, 0), first_entry.sequence);
    try std.testing.expectEqual(@as(?[32]u8, null), first_entry.prev_hash);
    
    const second_entry = journal.getEntry(1).?;
    try std.testing.expectEqual(@as(u64, 1), second_entry.sequence);
    try std.testing.expect(second_entry.prev_hash != null);
    try std.testing.expect(zcrypto.util.constantTimeCompare(&(second_entry.prev_hash.?), &first_entry.hash));
}

test "journal file persistence" {
    const allocator = std.testing.allocator;
    const test_file = "test_journal.log";
    
    {
        var journal = Journal.init(allocator, test_file);
        defer journal.deinit();

        const transaction = try tx.Transaction.init(allocator, 100000, "USD", "alice", "bob", "Test payment");
        try journal.append(transaction);
        
        try journal.saveToFile(test_file);
    }
    
    {
        var journal2 = Journal.init(allocator, null);
        defer journal2.deinit();
        
        try journal2.loadFromFile(test_file);
        try std.testing.expectEqual(@as(usize, 1), journal2.entries.items.len);
        try std.testing.expect(try journal2.verifyIntegrity());
    }
    
    std.fs.cwd().deleteFile(test_file) catch {};
}
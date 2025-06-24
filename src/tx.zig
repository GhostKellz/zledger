const std = @import("std");
const crypto = std.crypto;

pub const Transaction = struct {
    id: []const u8,
    timestamp: i64,
    amount: i64,
    currency: []const u8,
    from_account: []const u8,
    to_account: []const u8,
    memo: ?[]const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        amount: i64,
        currency: []const u8,
        from_account: []const u8,
        to_account: []const u8,
        memo: ?[]const u8,
    ) !Transaction {
        const timestamp = std.time.timestamp();
        const id = try generateTxId(allocator, timestamp, from_account, to_account, amount);
        
        return Transaction{
            .id = id,
            .timestamp = timestamp,
            .amount = amount,
            .currency = try allocator.dupe(u8, currency),
            .from_account = try allocator.dupe(u8, from_account),
            .to_account = try allocator.dupe(u8, to_account),
            .memo = if (memo) |m| try allocator.dupe(u8, m) else null,
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

        const json_value = std.json.Value{ .object = json_obj };
        return try std.json.stringifyAlloc(allocator, json_value, .{});
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

        return Transaction{
            .id = id,
            .timestamp = timestamp,
            .amount = amount,
            .currency = currency,
            .from_account = from_account,
            .to_account = to_account,
            .memo = memo,
        };
    }

    pub fn getHash(self: Transaction, allocator: std.mem.Allocator) ![32]u8 {
        const tx_data = try self.toJson(allocator);
        defer allocator.free(tx_data);
        
        var hash: [32]u8 = undefined;
        crypto.hash.sha2.Sha256.hash(tx_data, &hash, .{});
        return hash;
    }
};

fn generateTxId(allocator: std.mem.Allocator, timestamp: i64, from: []const u8, to: []const u8, amount: i64) ![]u8 {
    const id_data = try std.fmt.allocPrint(allocator, "{d}-{s}-{s}-{d}", .{ timestamp, from, to, amount });
    defer allocator.free(id_data);
    
    var hash: [32]u8 = undefined;
    crypto.hash.sha2.Sha256.hash(id_data, &hash, .{});
    
    return try std.fmt.allocPrint(allocator, "{x}", .{std.fmt.fmtSliceHexLower(hash[0..8])});
}

test "transaction creation and serialization" {
    const allocator = std.testing.allocator;
    
    var tx = try Transaction.init(
        allocator,
        100000,
        "USD",
        "alice",
        "bob",
        "Test payment"
    );
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
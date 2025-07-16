// Simple test for transaction dependency logic
const std = @import("std");

const MockTransaction = struct {
    id: []const u8,
    depends_on: ?[]const u8,

    pub fn validateDependencies(self: MockTransaction, processed_transactions: *const std.HashMap([]const u8, void, std.hash_map.StringContext, std.hash_map.default_max_load_percentage)) !void {
        if (self.depends_on) |dep_id| {
            if (!processed_transactions.contains(dep_id)) {
                return error.DependencyNotFound;
            }
        }
    }
};

test "dependency validation logic works" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var processed_txs = std.HashMap([]const u8, void, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator);
    defer processed_txs.deinit();

    // Add a processed transaction
    try processed_txs.put("tx1", {});

    // Test transaction without dependency - should pass
    const tx_no_dep = MockTransaction{ .id = "tx2", .depends_on = null };
    try tx_no_dep.validateDependencies(&processed_txs);

    // Test transaction with valid dependency - should pass
    const tx_valid_dep = MockTransaction{ .id = "tx3", .depends_on = "tx1" };
    try tx_valid_dep.validateDependencies(&processed_txs);

    // Test transaction with invalid dependency - should fail
    const tx_invalid_dep = MockTransaction{ .id = "tx4", .depends_on = "nonexistent" };
    try std.testing.expectError(error.DependencyNotFound, tx_invalid_dep.validateDependencies(&processed_txs));

    std.debug.print("✅ All dependency validation tests passed!\n", .{});
}

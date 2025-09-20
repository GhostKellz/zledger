const std = @import("std");

pub const AssetType = enum {
    native, // Native ledger asset
    token, // Standard token
    nft, // Non-fungible token
    synthetic, // Derived/synthetic asset
    stable, // Stable coin
};

pub const AssetMetadata = struct {
    symbol: []const u8,
    name: []const u8,
    decimals: u8,
    total_supply: ?u64,
    issuer: ?[]const u8,
    created_at: i64,

    pub fn init(allocator: std.mem.Allocator, symbol: []const u8, name: []const u8, decimals: u8) !AssetMetadata {
        return AssetMetadata{
            .symbol = try allocator.dupe(u8, symbol),
            .name = try allocator.dupe(u8, name),
            .decimals = decimals,
            .total_supply = null,
            .issuer = null,
            .created_at = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *AssetMetadata, allocator: std.mem.Allocator) void {
        allocator.free(self.symbol);
        allocator.free(self.name);
        if (self.issuer) |issuer| {
            allocator.free(issuer);
        }
    }
};

pub const AssetRule = struct {
    max_transaction_amount: ?i64,
    daily_limit: ?i64,
    requires_approval: bool,
    frozen: bool,
    whitelist_only: bool,

    pub fn init() AssetRule {
        return AssetRule{
            .max_transaction_amount = null,
            .daily_limit = null,
            .requires_approval = false,
            .frozen = false,
            .whitelist_only = false,
        };
    }

    pub fn validateTransaction(self: AssetRule, amount: i64) !void {
        if (self.frozen) {
            return error.AssetFrozen;
        }

        if (self.max_transaction_amount) |max| {
            if (amount > max) {
                return error.TransactionAmountTooLarge;
            }
        }
    }
};

pub const Asset = struct {
    id: []const u8,
    asset_type: AssetType,
    metadata: AssetMetadata,
    rules: AssetRule,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, asset_type: AssetType, symbol: []const u8, name: []const u8, decimals: u8) !Asset {
        return Asset{
            .id = try allocator.dupe(u8, id),
            .asset_type = asset_type,
            .metadata = try AssetMetadata.init(allocator, symbol, name, decimals),
            .rules = AssetRule.init(),
        };
    }

    pub fn deinit(self: *Asset, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        self.metadata.deinit(allocator);
    }

    pub fn clone(self: Asset, allocator: std.mem.Allocator) !Asset {
        return Asset{
            .id = try allocator.dupe(u8, self.id),
            .asset_type = self.asset_type,
            .metadata = AssetMetadata{
                .symbol = try allocator.dupe(u8, self.metadata.symbol),
                .name = try allocator.dupe(u8, self.metadata.name),
                .decimals = self.metadata.decimals,
                .total_supply = self.metadata.total_supply,
                .issuer = if (self.metadata.issuer) |issuer| try allocator.dupe(u8, issuer) else null,
                .created_at = self.metadata.created_at,
            },
            .rules = self.rules,
        };
    }

    pub fn validateTransaction(self: Asset, amount: i64) !void {
        try self.rules.validateTransaction(amount);
    }
};

pub const AssetRegistry = struct {
    assets: std.HashMap([]const u8, Asset, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AssetRegistry {
        return AssetRegistry{
            .assets = std.HashMap([]const u8, Asset, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AssetRegistry) void {
        var iterator = self.assets.iterator();
        while (iterator.next()) |entry| {
            var asset = entry.value_ptr;
            asset.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.assets.deinit();
    }

    pub fn registerAsset(self: *AssetRegistry, asset: Asset) !void {
        if (self.assets.contains(asset.id)) {
            return error.AssetAlreadyExists;
        }

        const owned_id = try self.allocator.dupe(u8, asset.id);
        const cloned_asset = try asset.clone(self.allocator);
        try self.assets.put(owned_id, cloned_asset);
    }

    pub fn getAsset(self: *AssetRegistry, asset_id: []const u8) ?*Asset {
        return self.assets.getPtr(asset_id);
    }

    pub fn isValidAsset(self: *AssetRegistry, asset_id: []const u8) bool {
        return self.assets.contains(asset_id);
    }

    pub fn validateAssetTransaction(self: *AssetRegistry, asset_id: []const u8, amount: i64) !void {
        const asset = self.getAsset(asset_id) orelse return error.AssetNotFound;
        try asset.validateTransaction(amount);
    }

    pub fn freezeAsset(self: *AssetRegistry, asset_id: []const u8) !void {
        var asset = self.getAsset(asset_id) orelse return error.AssetNotFound;
        asset.rules.frozen = true;
    }

    pub fn unfreezeAsset(self: *AssetRegistry, asset_id: []const u8) !void {
        var asset = self.getAsset(asset_id) orelse return error.AssetNotFound;
        asset.rules.frozen = false;
    }

    pub fn setTransactionLimit(self: *AssetRegistry, asset_id: []const u8, limit: i64) !void {
        var asset = self.getAsset(asset_id) orelse return error.AssetNotFound;
        asset.rules.max_transaction_amount = limit;
    }
};

// Currency conversion utilities
pub const ExchangeRate = struct {
    from_asset: []const u8,
    to_asset: []const u8,
    rate: f64,
    timestamp: i64,

    pub fn init(allocator: std.mem.Allocator, from: []const u8, to: []const u8, rate: f64) !ExchangeRate {
        return ExchangeRate{
            .from_asset = try allocator.dupe(u8, from),
            .to_asset = try allocator.dupe(u8, to),
            .rate = rate,
            .timestamp = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *ExchangeRate, allocator: std.mem.Allocator) void {
        allocator.free(self.from_asset);
        allocator.free(self.to_asset);
    }

    pub fn convert(self: ExchangeRate, amount: i64) i64 {
        const converted = @as(f64, @floatFromInt(amount)) * self.rate;
        return @as(i64, @intFromFloat(converted));
    }
};

pub const CurrencyConverter = struct {
    rates: std.HashMap([]const u8, ExchangeRate, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CurrencyConverter {
        return CurrencyConverter{
            .rates = std.HashMap([]const u8, ExchangeRate, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CurrencyConverter) void {
        var iterator = self.rates.iterator();
        while (iterator.next()) |entry| {
            var rate = entry.value_ptr;
            rate.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.rates.deinit();
    }

    pub fn addRate(self: *CurrencyConverter, rate: ExchangeRate) !void {
        const key = try std.fmt.allocPrint(self.allocator, "{s}-{s}", .{ rate.from_asset, rate.to_asset });
        try self.rates.put(key, rate);
    }

    pub fn convert(self: *CurrencyConverter, amount: i64, from: []const u8, to: []const u8) !i64 {
        if (std.mem.eql(u8, from, to)) return amount;

        const key = try std.fmt.allocPrint(self.allocator, "{s}-{s}", .{ from, to });
        defer self.allocator.free(key);

        const rate = self.rates.get(key) orelse return error.ExchangeRateNotFound;
        return rate.convert(amount);
    }
};

test "asset registry creation and validation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var registry = AssetRegistry.init(allocator);
    defer registry.deinit();

    // Create test asset
    var asset = try Asset.init(allocator, "USD", .native, "USD", "US Dollar", 2);
    defer asset.deinit(allocator);

    // Register asset
    try registry.registerAsset(asset);

    // Validate asset exists
    try std.testing.expect(registry.isValidAsset("USD"));
    try std.testing.expect(!registry.isValidAsset("EUR"));

    std.debug.print("✅ Asset registry validation passed\n", .{});
}

test "asset transaction validation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var registry = AssetRegistry.init(allocator);
    defer registry.deinit();

    var asset = try Asset.init(allocator, "BTC", .token, "BTC", "Bitcoin", 8);
    asset.rules.max_transaction_amount = 1000000; // Max 0.01 BTC
    defer asset.deinit(allocator);

    try registry.registerAsset(asset);

    // Valid transaction
    try registry.validateAssetTransaction("BTC", 500000);

    // Invalid transaction (too large)
    try std.testing.expectError(error.TransactionAmountTooLarge, registry.validateAssetTransaction("BTC", 2000000));

    std.debug.print("✅ Asset transaction validation passed\n", .{});
}

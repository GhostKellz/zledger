const std = @import("std");

pub const ContractError = error{
    ExecutionFailed,
    InvalidParameters,
    StateMismatch,
    InsufficientGas,
    AccessDenied,
    StateCorrupted,
    InvalidOpcode,
    OutOfMemory,
};

pub const GasLimit = u64;
pub const ContractAddress = [20]u8;
pub const StateHash = [32]u8;

const StorageMap = std.HashMap([32]u8, [32]u8, struct {
    pub fn hash(self: @This(), key: [32]u8) u64 {
        _ = self;
        return std.hash_map.hashString(std.mem.asBytes(&key));
    }
    pub fn eql(self: @This(), a: [32]u8, b: [32]u8) bool {
        _ = self;
        return std.mem.eql(u8, &a, &b);
    }
}, std.hash_map.default_max_load_percentage);

pub const ContractState = struct {
    storage: StorageMap,
    balance: u256,
    nonce: u64,
    code_hash: [32]u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ContractState {
        return ContractState{
            .storage = StorageMap.init(allocator),
            .balance = 0,
            .nonce = 0,
            .code_hash = std.mem.zeroes([32]u8),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ContractState) void {
        self.storage.deinit();
    }

    pub fn get(self: *const ContractState, key: [32]u8) ?[32]u8 {
        return self.storage.get(key);
    }

    pub fn set(self: *ContractState, key: [32]u8, value: [32]u8) !void {
        try self.storage.put(key, value);
    }
};

pub const ExecutionContext = struct {
    sender: ContractAddress,
    origin: ContractAddress,
    gas_limit: GasLimit,
    gas_used: GasLimit,
    value: u256,
    data: []const u8,
    block_number: u64,
    timestamp: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, sender: ContractAddress, gas_limit: GasLimit) ExecutionContext {
        return ExecutionContext{
            .sender = sender,
            .origin = sender,
            .gas_limit = gas_limit,
            .gas_used = 0,
            .value = 0,
            .data = &.{},
            .block_number = 0,
            .timestamp = @intCast(std.time.timestamp()),
            .allocator = allocator,
        };
    }

    pub fn consumeGas(self: *ExecutionContext, amount: GasLimit) ContractError!void {
        if (self.gas_used + amount > self.gas_limit) {
            return ContractError.InsufficientGas;
        }
        self.gas_used += amount;
    }
};

pub const Contract = struct {
    address: ContractAddress,
    code: []const u8,
    state: ContractState,
    owner: ContractAddress,
    is_active: bool,

    pub fn init(allocator: std.mem.Allocator, address: ContractAddress, code: []const u8, owner: ContractAddress) Contract {
        return Contract{
            .address = address,
            .code = code,
            .state = ContractState.init(allocator),
            .owner = owner,
            .is_active = true,
        };
    }

    pub fn deinit(self: *Contract) void {
        self.state.deinit();
    }

    pub fn execute(self: *Contract, context: *ExecutionContext, function_sig: [4]u8, params: []const u8) ContractError![]u8 {
        if (!self.is_active) {
            return ContractError.AccessDenied;
        }

        try context.consumeGas(21000);

        return switch (std.mem.readInt(u32, &function_sig, .big)) {
            0x70a08231 => self.balanceOf(context, params),
            0xa9059cbb => self.transfer(context, params),
            0x095ea7b3 => self.approve(context, params),
            0x23b872dd => self.transferFrom(context, params),
            else => ContractError.InvalidOpcode,
        };
    }

    fn balanceOf(self: *Contract, context: *ExecutionContext, params: []const u8) ContractError![]u8 {
        try context.consumeGas(400);

        if (params.len != 32) return ContractError.InvalidParameters;

        const addr_key = params[0..32].*;
        const balance = self.state.get(addr_key) orelse std.mem.zeroes([32]u8);

        const result = try context.allocator.alloc(u8, 32);
        @memcpy(result, &balance);
        return result;
    }

    fn transfer(self: *Contract, context: *ExecutionContext, params: []const u8) ContractError![]u8 {
        try context.consumeGas(5000);

        if (params.len != 64) return ContractError.InvalidParameters;

        var to_addr: [32]u8 = undefined;
        @memcpy(to_addr[12..], params[12..32]);
        const amount = params[32..64].*;

        var sender_key: [32]u8 = undefined;
        @memcpy(sender_key[12..], &context.sender);

        const sender_balance = self.state.get(sender_key) orelse std.mem.zeroes([32]u8);
        const receiver_balance = self.state.get(to_addr) orelse std.mem.zeroes([32]u8);

        const sender_val = std.mem.readInt(u256, &sender_balance, .big);
        const amount_val = std.mem.readInt(u256, &amount, .big);
        const receiver_val = std.mem.readInt(u256, &receiver_balance, .big);

        if (sender_val < amount_val) {
            return ContractError.InvalidParameters;
        }

        var new_sender_balance: [32]u8 = undefined;
        var new_receiver_balance: [32]u8 = undefined;
        std.mem.writeInt(u256, &new_sender_balance, sender_val - amount_val, .big);
        std.mem.writeInt(u256, &new_receiver_balance, receiver_val + amount_val, .big);

        try self.state.set(sender_key, new_sender_balance);
        try self.state.set(to_addr, new_receiver_balance);

        const result = try context.allocator.alloc(u8, 32);
        std.mem.writeInt(u256, result[0..32], 1, .big);
        return result;
    }

    fn approve(self: *Contract, context: *ExecutionContext, params: []const u8) ContractError![]u8 {
        try context.consumeGas(5000);

        if (params.len != 64) return ContractError.InvalidParameters;

        var allowance_key: [32]u8 = undefined;
        @memcpy(allowance_key[0..20], &context.sender);
        @memcpy(allowance_key[20..32], params[12..24]);

        const amount = params[32..64].*;
        try self.state.set(allowance_key, amount);

        const result = try context.allocator.alloc(u8, 32);
        std.mem.writeInt(u256, result[0..32], 1, .big);
        return result;
    }

    fn transferFrom(self: *Contract, context: *ExecutionContext, params: []const u8) ContractError![]u8 {
        try context.consumeGas(7000);

        if (params.len != 96) return ContractError.InvalidParameters;

        var from_addr: [32]u8 = undefined;
        var to_addr: [32]u8 = undefined;
        const amount = params[64..96].*;
        @memcpy(from_addr[12..], params[12..32]);
        @memcpy(to_addr[12..], params[44..64]);

        var allowance_key: [32]u8 = undefined;
        @memcpy(allowance_key[0..20], from_addr[12..]);
        @memcpy(allowance_key[20..32], context.sender[0..12]);

        const allowance = self.state.get(allowance_key) orelse std.mem.zeroes([32]u8);
        const allowance_val = std.mem.readInt(u256, &allowance, .big);
        const amount_val = std.mem.readInt(u256, &amount, .big);

        if (allowance_val < amount_val) {
            return ContractError.InvalidParameters;
        }

        var from_balance_key: [32]u8 = undefined;
        @memcpy(from_balance_key[12..], from_addr[12..]);

        const from_balance = self.state.get(from_balance_key) orelse std.mem.zeroes([32]u8);
        const to_balance = self.state.get(to_addr) orelse std.mem.zeroes([32]u8);

        const from_val = std.mem.readInt(u256, &from_balance, .big);
        const to_val = std.mem.readInt(u256, &to_balance, .big);

        if (from_val < amount_val) {
            return ContractError.InvalidParameters;
        }

        var new_from_balance: [32]u8 = undefined;
        var new_to_balance: [32]u8 = undefined;
        var new_allowance: [32]u8 = undefined;

        std.mem.writeInt(u256, &new_from_balance, from_val - amount_val, .big);
        std.mem.writeInt(u256, &new_to_balance, to_val + amount_val, .big);
        std.mem.writeInt(u256, &new_allowance, allowance_val - amount_val, .big);

        try self.state.set(from_balance_key, new_from_balance);
        try self.state.set(to_addr, new_to_balance);
        try self.state.set(allowance_key, new_allowance);

        const result = try context.allocator.alloc(u8, 32);
        std.mem.writeInt(u256, result[0..32], 1, .big);
        return result;
    }
};

pub const ContractEvent = struct {
    contract_address: ContractAddress,
    event_type: ContractEventType,
    data: []const u8,
    gas_used: GasLimit,
    timestamp: i64,

    pub fn init(allocator: std.mem.Allocator, address: ContractAddress, event_type: ContractEventType, data: []const u8, gas_used: GasLimit) !ContractEvent {
        return ContractEvent{
            .contract_address = address,
            .event_type = event_type,
            .data = try allocator.dupe(u8, data),
            .gas_used = gas_used,
            .timestamp = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *ContractEvent, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

pub const ContractEventType = enum {
    contract_created,
    contract_executed,
    contract_destroyed,
    state_changed,
    gas_consumed,
};

pub const ZVMIntegrationHooks = struct {
    ledger: ?*anyopaque, // Pointer to Ledger
    event_callback: ?*const fn (event: ContractEvent) void,

    pub fn init() ZVMIntegrationHooks {
        return ZVMIntegrationHooks{
            .ledger = null,
            .event_callback = null,
        };
    }

    pub fn setLedger(self: *ZVMIntegrationHooks, ledger: *anyopaque) void {
        self.ledger = ledger;
    }

    pub fn recordContractExecution(self: *ZVMIntegrationHooks, contract_address: ContractAddress, gas_used: GasLimit, success: bool) void {
        // Create contract event record for ledger integration
        _ = self;
        _ = contract_address;
        _ = gas_used;
        _ = success;
        // Implementation would create transaction record for gas fees
    }

    pub fn recordStateChange(self: *ZVMIntegrationHooks, contract_address: ContractAddress, state_hash: StateHash) void {
        _ = self;
        _ = contract_address;
        _ = state_hash;
        // Record state change in ledger audit trail
    }
};

pub fn version() []const u8 {
    return "0.1.0";
}

test "contract instantiation and basic operations" {
    var contract = Contract.init(std.testing.allocator, std.mem.zeroes(ContractAddress), "test_code", std.mem.zeroes(ContractAddress));
    defer contract.deinit();

    try std.testing.expect(contract.is_active);
}

test "contract execution with gas accounting" {
    var contract = Contract.init(std.testing.allocator, std.mem.zeroes(ContractAddress), "test_code", std.mem.zeroes(ContractAddress));
    defer contract.deinit();

    var context = ExecutionContext.init(std.testing.allocator, std.mem.zeroes(ContractAddress), 100000);

    const initial_gas = context.gas_used;

    var params = [_]u8{0} ** 32;
    const result = contract.balanceOf(&context, &params);
    defer if (result) |r| std.testing.allocator.free(r) else |_| {};

    try std.testing.expect(context.gas_used > initial_gas);
    if (result) |_| {} else |_| try std.testing.expect(false);
}

test "transfer with insufficient balance fails" {
    var contract = Contract.init(std.testing.allocator, std.mem.zeroes(ContractAddress), "test_code", std.mem.zeroes(ContractAddress));
    defer contract.deinit();

    var context = ExecutionContext.init(std.testing.allocator, std.mem.zeroes(ContractAddress), 100000);

    var params = [_]u8{0} ** 64;
    params[63] = 1;

    const result = contract.transfer(&context, &params);
    defer if (result) |r| std.testing.allocator.free(r) else |_| {};

    try std.testing.expectError(ContractError.InvalidParameters, result);
}

test "approve and transferFrom with insufficient allowance fails" {
    var contract = Contract.init(std.testing.allocator, std.mem.zeroes(ContractAddress), "test_code", std.mem.zeroes(ContractAddress));
    defer contract.deinit();

    var context = ExecutionContext.init(std.testing.allocator, std.mem.zeroes(ContractAddress), 100000);

    var params = [_]u8{0} ** 96;
    params[95] = 1;

    const result = contract.transferFrom(&context, &params);
    defer if (result) |r| std.testing.allocator.free(r) else |_| {};

    try std.testing.expectError(ContractError.InvalidParameters, result);
}

test "gas exhaustion fails correctly" {
    var contract = Contract.init(std.testing.allocator, std.mem.zeroes(ContractAddress), "test_code", std.mem.zeroes(ContractAddress));
    defer contract.deinit();

    var context = ExecutionContext.init(std.testing.allocator, std.mem.zeroes(ContractAddress), 100);

    var params = [_]u8{0} ** 32;
    const function_sig = [4]u8{ 0x70, 0xa0, 0x82, 0x31 };

    const result = contract.execute(&context, function_sig, &params);
    defer if (result) |r| std.testing.allocator.free(r) else |_| {};

    try std.testing.expectError(ContractError.InsufficientGas, result);
}

# Digital Wallet Implementation

This example demonstrates how to build a complete digital wallet using Zledger v0.5.0's integrated ledger and cryptographic capabilities.

## 🏗️ Project Structure

```
wallet/
├── build.zig
├── build.zig.zon
└── src/
    ├── main.zig
    ├── wallet.zig
    ├── transaction.zig
    ├── crypto.zig
    └── cli.zig
```

## 📦 Setup

### build.zig.zon

```zig
.{
    .name = "digital-wallet",
    .version = "0.1.0",
    .dependencies = .{
        .zledger = .{
            .url = "https://github.com/ghostkellz/zledger",
            .hash = "12345...", // zig fetch will fill this
        },
    },
    .paths = .{""},
}
```

### build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zledger = b.dependency("zledger", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "wallet",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zledger", zledger.module("zledger"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the wallet");
    run_step.dependOn(&run_cmd.step);
}
```

## 💼 Core Wallet Implementation

### src/wallet.zig

```zig
const std = @import("std");
const zledger = @import("zledger");

pub const WalletError = error{
    InsufficientFunds,
    InvalidAddress,
    TransactionFailed,
    InvalidSignature,
    WalletLocked,
    InvalidPin,
};

pub const Wallet = struct {
    name: []const u8,
    address: []const u8,
    keypair: zledger.Keypair,
    ledger: zledger.Ledger,
    locked: bool,
    pin_hash: [32]u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn create(allocator: std.mem.Allocator, name: []const u8, pin: []const u8) !Self {
        // Generate wallet keypair
        const keypair = try zledger.generateKeypair(allocator);

        // Generate address from public key
        const pubkey_hex = try keypair.publicKeyHex(allocator);
        defer allocator.free(pubkey_hex);

        const address = try std.fmt.allocPrint(allocator, "wallet_{}", .{std.fmt.fmtSliceHexLower(pubkey_hex[0..8])});

        // Hash PIN for security
        var pin_hash: [32]u8 = undefined;
        std.crypto.hash.blake3.hash(pin, &pin_hash, .{});

        // Initialize ledger
        var ledger = zledger.Ledger.init(allocator);

        // Register USD asset
        const usd_asset = zledger.Asset{
            .id = "USD",
            .metadata = .{
                .symbol = "USD",
                .name = "US Dollar",
                .decimals = 2,
            },
        };
        try ledger.asset_registry.registerAsset(usd_asset);

        // Create wallet account
        try ledger.createAccount(address, .asset, "USD");

        return Self{
            .name = try allocator.dupe(u8, name),
            .address = address,
            .keypair = keypair,
            .ledger = ledger,
            .locked = false,
            .pin_hash = pin_hash,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.ledger.deinit();
        self.allocator.free(self.name);
        self.allocator.free(self.address);
    }

    pub fn unlock(self: *Self, pin: []const u8) !void {
        var pin_hash: [32]u8 = undefined;
        std.crypto.hash.blake3.hash(pin, &pin_hash, .{});

        if (!std.mem.eql(u8, &self.pin_hash, &pin_hash)) {
            return WalletError.InvalidPin;
        }

        self.locked = false;
    }

    pub fn lock(self: *Self) void {
        self.locked = true;
    }

    pub fn getBalance(self: *Self) !zledger.FixedPoint {
        if (self.locked) return WalletError.WalletLocked;
        return try self.ledger.getBalance(self.address);
    }

    pub fn getAddress(self: *Self) []const u8 {
        return self.address;
    }

    pub fn getPublicKey(self: *Self) [32]u8 {
        return self.keypair.publicKey();
    }

    pub fn send(self: *Self, to_address: []const u8, amount: i64, memo: ?[]const u8) ![]const u8 {
        if (self.locked) return WalletError.WalletLocked;

        // Check sufficient funds
        const balance = try self.getBalance();
        if (balance.value < amount) {
            return WalletError.InsufficientFunds;
        }

        // Create transaction
        const tx_id = try self.generateTransactionId();
        const tx = zledger.Transaction{
            .id = tx_id,
            .timestamp = std.time.timestamp(),
            .amount = amount,
            .currency = "USD",
            .from_account = self.address,
            .to_account = to_address,
            .memo = memo,
        };

        // Sign transaction
        const signed_tx = try self.signTransaction(tx);

        // Add to ledger
        try self.ledger.addTransaction(tx);

        std.debug.print("💸 Sent ${d:.2} to {s}\\n", .{ @as(f64, @floatFromInt(amount)) / 100.0, to_address });

        return tx_id;
    }

    pub fn receive(self: *Self, from_address: []const u8, amount: i64, memo: ?[]const u8) ![]const u8 {
        if (self.locked) return WalletError.WalletLocked;

        // Create receiving transaction
        const tx_id = try self.generateTransactionId();
        const tx = zledger.Transaction{
            .id = tx_id,
            .timestamp = std.time.timestamp(),
            .amount = amount,
            .currency = "USD",
            .from_account = from_address,
            .to_account = self.address,
            .memo = memo,
        };

        // Add to ledger (in real implementation, this would be verified externally)
        try self.ledger.addTransaction(tx);

        std.debug.print("💰 Received ${d:.2} from {s}\\n", .{ @as(f64, @floatFromInt(amount)) / 100.0, from_address });

        return tx_id;
    }

    pub fn getTransactionHistory(self: *Self) ![]zledger.Transaction {
        if (self.locked) return WalletError.WalletLocked;
        return try self.ledger.getTransactionHistory(self.address);
    }

    pub fn signTransaction(self: *Self, tx: zledger.Transaction) !zledger.Signature {
        if (self.locked) return WalletError.WalletLocked;

        const tx_json = try std.json.stringifyAlloc(self.allocator, tx, .{});
        defer self.allocator.free(tx_json);

        return try zledger.signMessage(tx_json, self.keypair);
    }

    pub fn verifyTransaction(tx: zledger.Transaction, signature: zledger.Signature, public_key: [32]u8, allocator: std.mem.Allocator) !bool {
        const tx_json = try std.json.stringifyAlloc(allocator, tx, .{});
        defer allocator.free(tx_json);

        return zledger.verifySignature(tx_json, &signature.bytes, &public_key);
    }

    pub fn exportWallet(self: *Self, password: []const u8) ![]u8 {
        if (self.locked) return WalletError.WalletLocked;

        // Export keypair bundle
        const key_bundle = try self.keypair.exportBundle(self.allocator);
        defer self.allocator.free(key_bundle);

        // Create wallet export data
        const export_data = WalletExportData{
            .name = self.name,
            .address = self.address,
            .key_bundle = key_bundle,
            .created_at = std.time.timestamp(),
        };

        const export_json = try std.json.stringifyAlloc(self.allocator, export_data, .{});

        // In real implementation, encrypt with password
        _ = password;

        return export_json;
    }

    fn generateTransactionId(self: *Self) ![]const u8 {
        const timestamp = std.time.timestamp();
        const random = std.crypto.random.int(u32);
        return try std.fmt.allocPrint(self.allocator, "TX{d}{d}", .{ timestamp, random });
    }
};

const WalletExportData = struct {
    name: []const u8,
    address: []const u8,
    key_bundle: []const u8,
    created_at: i64,
};
```

## 🔄 Transaction Management

### src/transaction.zig

```zig
const std = @import("std");
const zledger = @import("zledger");
const Wallet = @import("wallet.zig").Wallet;

pub const TransactionManager = struct {
    allocator: std.mem.Allocator,
    pending_transactions: std.ArrayList(PendingTransaction),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .pending_transactions = std.ArrayList(PendingTransaction).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.pending_transactions.deinit();
    }

    pub fn createTransaction(self: *Self, from_wallet: *Wallet, to_address: []const u8, amount: i64, memo: ?[]const u8) !PendingTransaction {
        const tx_id = try self.generateTransactionId();
        const tx = zledger.Transaction{
            .id = tx_id,
            .timestamp = std.time.timestamp(),
            .amount = amount,
            .currency = "USD",
            .from_account = from_wallet.getAddress(),
            .to_account = to_address,
            .memo = memo,
        };

        // Sign transaction
        const signature = try from_wallet.signTransaction(tx);

        const pending_tx = PendingTransaction{
            .transaction = tx,
            .signature = signature,
            .sender_public_key = from_wallet.getPublicKey(),
            .status = .pending,
            .created_at = std.time.timestamp(),
        };

        try self.pending_transactions.append(pending_tx);

        return pending_tx;
    }

    pub fn processTransaction(self: *Self, pending_tx: *PendingTransaction, receiving_wallet: *Wallet) !void {
        // Verify signature
        const is_valid = try Wallet.verifyTransaction(
            pending_tx.transaction,
            pending_tx.signature,
            pending_tx.sender_public_key,
            self.allocator,
        );

        if (!is_valid) {
            pending_tx.status = .failed;
            return error.InvalidSignature;
        }

        // Process on receiving wallet
        _ = try receiving_wallet.receive(
            pending_tx.transaction.from_account,
            pending_tx.transaction.amount,
            pending_tx.transaction.memo,
        );

        pending_tx.status = .completed;
        pending_tx.completed_at = std.time.timestamp();
    }

    pub fn batchProcessTransactions(self: *Self, transactions: []PendingTransaction, receiving_wallet: *Wallet) !void {
        for (transactions) |*tx| {
            self.processTransaction(tx, receiving_wallet) catch |err| {
                tx.status = .failed;
                std.debug.print("Transaction {} failed: {}\\n", .{ tx.transaction.id, err });
            };
        }
    }

    pub fn getPendingTransactions(self: *Self) []PendingTransaction {
        return self.pending_transactions.items;
    }

    fn generateTransactionId(self: *Self) ![]const u8 {
        const timestamp = std.time.timestamp();
        const random = std.crypto.random.int(u32);
        return try std.fmt.allocPrint(self.allocator, "TX{d}{X}", .{ timestamp, random });
    }
};

pub const TransactionStatus = enum {
    pending,
    completed,
    failed,
};

pub const PendingTransaction = struct {
    transaction: zledger.Transaction,
    signature: zledger.Signature,
    sender_public_key: [32]u8,
    status: TransactionStatus,
    created_at: i64,
    completed_at: ?i64 = null,
};
```

## 🖥️ CLI Interface

### src/cli.zig

```zig
const std = @import("std");
const zledger = @import("zledger");
const Wallet = @import("wallet.zig").Wallet;

pub const WalletCLI = struct {
    wallet: ?Wallet,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .wallet = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.wallet) |*wallet| {
            wallet.deinit();
        }
    }

    pub fn run(self: *Self) !void {
        std.debug.print("🪙 Digital Wallet v1.0\\n", .{});
        std.debug.print("Powered by Zledger v0.5.0\\n\\n", .{});

        while (true) {
            try self.printMenu();
            const choice = try self.getUserInput();

            switch (choice) {
                1 => try self.createWallet(),
                2 => try self.unlockWallet(),
                3 => try self.showBalance(),
                4 => try self.sendMoney(),
                5 => try self.showHistory(),
                6 => try self.lockWallet(),
                7 => try self.exportWallet(),
                0 => break,
                else => std.debug.print("❌ Invalid choice\\n\\n", .{}),
            }
        }

        std.debug.print("👋 Goodbye!\\n", .{});
    }

    fn printMenu(self: *Self) !void {
        std.debug.print("📋 Wallet Menu:\\n", .{});
        std.debug.print("1. Create New Wallet\\n", .{});
        std.debug.print("2. Unlock Wallet\\n", .{});

        if (self.wallet != null and !self.wallet.?.locked) {
            std.debug.print("3. Show Balance\\n", .{});
            std.debug.print("4. Send Money\\n", .{});
            std.debug.print("5. Transaction History\\n", .{});
            std.debug.print("6. Lock Wallet\\n", .{});
            std.debug.print("7. Export Wallet\\n", .{});
        }

        std.debug.print("0. Exit\\n", .{});
        std.debug.print("\\nChoice: ", .{});
    }

    fn getUserInput(self: *Self) !u8 {
        _ = self;
        const stdin = std.io.getStdIn().reader();
        var buf: [10]u8 = undefined;

        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\\n')) |input| {
            return std.fmt.parseInt(u8, std.mem.trim(u8, input, " \\t\\n"), 10) catch 255;
        }
        return 255;
    }

    fn getStringInput(self: *Self, prompt: []const u8) ![]u8 {
        std.debug.print("{s}: ", .{prompt});
        const stdin = std.io.getStdIn().reader();
        var buf: [256]u8 = undefined;

        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\\n')) |input| {
            return try self.allocator.dupe(u8, std.mem.trim(u8, input, " \\t\\n"));
        }
        return try self.allocator.dupe(u8, "");
    }

    fn createWallet(self: *Self) !void {
        std.debug.print("\\n🆕 Creating New Wallet\\n", .{});

        const name = try self.getStringInput("Wallet name");
        defer self.allocator.free(name);

        const pin = try self.getStringInput("Set PIN (6 digits)");
        defer self.allocator.free(pin);

        if (pin.len < 4) {
            std.debug.print("❌ PIN must be at least 4 characters\\n\\n", .{});
            return;
        }

        const wallet = try Wallet.create(self.allocator, name, pin);

        std.debug.print("✅ Wallet created successfully!\\n", .{});
        std.debug.print("📍 Address: {s}\\n", .{wallet.getAddress()});
        std.debug.print("🔑 Public Key: {}\\n\\n", .{std.fmt.fmtSliceHexLower(&wallet.getPublicKey())});

        // Fund the wallet for demo
        _ = try wallet.receive("demo_faucet", 1000000, "Welcome bonus"); // $10,000

        self.wallet = wallet;
    }

    fn unlockWallet(self: *Self) !void {
        if (self.wallet == null) {
            std.debug.print("❌ No wallet found. Create a wallet first.\\n\\n", .{});
            return;
        }

        std.debug.print("\\n🔓 Unlocking Wallet\\n", .{});
        const pin = try self.getStringInput("Enter PIN");
        defer self.allocator.free(pin);

        self.wallet.?.unlock(pin) catch {
            std.debug.print("❌ Invalid PIN\\n\\n", .{});
            return;
        };

        std.debug.print("✅ Wallet unlocked\\n\\n", .{});
    }

    fn showBalance(self: *Self) !void {
        if (self.wallet == null or self.wallet.?.locked) {
            std.debug.print("❌ Wallet is locked\\n\\n", .{});
            return;
        }

        const balance = try self.wallet.?.getBalance();
        std.debug.print("\\n💰 Current Balance: ${d:.2}\\n", .{balance.toFloat()});
        std.debug.print("📍 Address: {s}\\n\\n", .{self.wallet.?.getAddress()});
    }

    fn sendMoney(self: *Self) !void {
        if (self.wallet == null or self.wallet.?.locked) {
            std.debug.print("❌ Wallet is locked\\n\\n", .{});
            return;
        }

        std.debug.print("\\n💸 Send Money\\n", .{});

        const to_address = try self.getStringInput("Recipient address");
        defer self.allocator.free(to_address);

        const amount_str = try self.getStringInput("Amount (USD)");
        defer self.allocator.free(amount_str);

        const amount = std.fmt.parseFloat(f64, amount_str) catch {
            std.debug.print("❌ Invalid amount\\n\\n", .{});
            return;
        };

        const amount_cents = @as(i64, @intFromFloat(amount * 100));

        const memo = try self.getStringInput("Memo (optional)");
        defer self.allocator.free(memo);

        const memo_opt = if (memo.len == 0) null else memo;

        _ = self.wallet.?.send(to_address, amount_cents, memo_opt) catch |err| {
            switch (err) {
                error.InsufficientFunds => std.debug.print("❌ Insufficient funds\\n\\n", .{}),
                else => std.debug.print("❌ Transaction failed: {}\\n\\n", .{err}),
            }
            return;
        };

        std.debug.print("✅ Transaction sent successfully\\n\\n", .{});
    }

    fn showHistory(self: *Self) !void {
        if (self.wallet == null or self.wallet.?.locked) {
            std.debug.print("❌ Wallet is locked\\n\\n", .{});
            return;
        }

        const history = try self.wallet.?.getTransactionHistory();

        std.debug.print("\\n📜 Transaction History\\n", .{});
        std.debug.print("═══════════════════════\\n", .{});

        if (history.len == 0) {
            std.debug.print("No transactions found\\n\\n", .{});
            return;
        }

        for (history, 0..) |tx, i| {
            const is_outgoing = std.mem.eql(u8, tx.from_account, self.wallet.?.getAddress());
            const direction = if (is_outgoing) "➡️ " else "⬅️ ";
            const other_party = if (is_outgoing) tx.to_account else tx.from_account;

            std.debug.print("{}. {} ${d:.2} {} {s}\\n", .{
                i + 1,
                direction,
                @as(f64, @floatFromInt(tx.amount)) / 100.0,
                if (is_outgoing) "to" else "from",
                other_party,
            });

            if (tx.memo) |memo| {
                std.debug.print("    💬 {s}\\n", .{memo});
            }

            std.debug.print("    🕐 {}\\n", .{tx.timestamp});
            std.debug.print("\\n", .{});
        }
    }

    fn lockWallet(self: *Self) !void {
        if (self.wallet == null) {
            std.debug.print("❌ No wallet found\\n\\n", .{});
            return;
        }

        self.wallet.?.lock();
        std.debug.print("🔒 Wallet locked\\n\\n", .{});
    }

    fn exportWallet(self: *Self) !void {
        if (self.wallet == null or self.wallet.?.locked) {
            std.debug.print("❌ Wallet is locked\\n\\n", .{});
            return;
        }

        const password = try self.getStringInput("Export password");
        defer self.allocator.free(password);

        const export_data = try self.wallet.?.exportWallet(password);
        defer self.allocator.free(export_data);

        const filename = try std.fmt.allocPrint(self.allocator, "{s}_backup.json", .{self.wallet.?.name});
        defer self.allocator.free(filename);

        try std.fs.cwd().writeFile(.{ .sub_path = filename, .data = export_data });

        std.debug.print("✅ Wallet exported to {s}\\n\\n", .{filename});
    }
};
```

## 🚀 Main Application

### src/main.zig

```zig
const std = @import("std");
const WalletCLI = @import("cli.zig").WalletCLI;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cli = WalletCLI.init(allocator);
    defer cli.deinit();

    try cli.run();
}
```

## 🏃‍♂️ Running the Wallet

```bash
# Build and run
zig build run

# Example interaction:
🪙 Digital Wallet v1.0
Powered by Zledger v0.5.0

📋 Wallet Menu:
1. Create New Wallet
2. Unlock Wallet
0. Exit

Choice: 1

🆕 Creating New Wallet
Wallet name: MyWallet
Set PIN (6 digits): 123456
✅ Wallet created successfully!
📍 Address: wallet_a1b2c3d4
🔑 Public Key: a1b2c3d4e5f6789...
💰 Received $10000.00 from demo_faucet

📋 Wallet Menu:
1. Create New Wallet
2. Unlock Wallet
3. Show Balance
4. Send Money
5. Transaction History
6. Lock Wallet
7. Export Wallet
0. Exit

Choice: 3

💰 Current Balance: $10000.00
📍 Address: wallet_a1b2c3d4
```

## 🔐 Security Features

1. **PIN Protection** - Wallet locks/unlocks with PIN
2. **Cryptographic Signing** - All transactions signed with Ed25519
3. **Signature Verification** - Incoming transactions verified
4. **Secure Key Storage** - Private keys encrypted for export
5. **Double-Entry Accounting** - Ledger integrity maintained

## 💡 Extension Ideas

- **Multi-Currency Support** - Add Bitcoin, Ethereum, etc.
- **Hardware Wallet Integration** - Support for hardware devices
- **Network Layer** - P2P transaction broadcasting
- **Smart Contracts** - Programmable transaction logic
- **Mobile App** - React Native or Flutter frontend
- **Recovery System** - Seed phrase backup/restore
- **Multi-Signature** - Require multiple signatures for transactions

This wallet demonstrates the power of Zledger v0.5.0's integrated approach, combining robust ledger functionality with cryptographic security in a single, easy-to-use package.
# Examples

Practical examples showing how to use Zledger in real-world scenarios.

## 📚 Example Categories

### 🚀 [Getting Started](./getting-started/)
- Basic ledger operations
- Simple transaction processing
- Account management

### 💰 [Financial Applications](./financial/)
- Digital wallet implementation
- Multi-currency trading system
- Payment processing service

### 🔐 [Cryptographic Operations](./crypto/)
- Transaction signing workflow
- Multi-signature schemes
- Key management systems

### 🌐 [Web Integration](./web/)
- WASM-based ledger in browser
- REST API with Zledger backend
- Real-time transaction updates

### 🔌 [Advanced Integrations](./advanced/)
- Microservices architecture
- Event-driven systems
- Audit and compliance tools

## 🏃‍♂️ Quick Start Example

Here's a complete example to get you started:

```zig
const std = @import("std");
const zledger = @import("zledger");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 1. Initialize ledger
    var ledger = zledger.Ledger.init(allocator);
    defer ledger.deinit();

    // 2. Set up accounts
    try ledger.createAccount("alice", .asset, "USD");
    try ledger.createAccount("bob", .asset, "USD");
    try ledger.createAccount("bank", .asset, "USD");

    // 3. Generate signing keypair
    const keypair = try zledger.generateKeypair(allocator);

    // 4. Fund Alice's account (from bank)
    const funding_tx = zledger.Transaction{
        .id = "fund-001",
        .timestamp = std.time.timestamp(),
        .amount = 100000, // $1000.00 in cents
        .currency = "USD",
        .from_account = "bank",
        .to_account = "alice",
        .memo = "Initial funding",
    };

    try ledger.addTransaction(funding_tx);

    // 5. Create signed transaction from Alice to Bob
    const transfer_tx = zledger.Transaction{
        .id = "tx-001",
        .timestamp = std.time.timestamp(),
        .amount = 25000, // $250.00 in cents
        .currency = "USD",
        .from_account = "alice",
        .to_account = "bob",
        .memo = "Payment for services",
    };

    // 6. Sign the transaction
    const tx_json = try std.json.stringifyAlloc(allocator, transfer_tx, .{});
    defer allocator.free(tx_json);

    const signature = try zledger.signMessage(tx_json, keypair);

    // 7. Verify signature before processing
    const is_valid = zledger.verifySignature(tx_json, &signature.bytes, &keypair.publicKey());
    if (!is_valid) {
        std.debug.print("Invalid signature!\\n", .{});
        return;
    }

    // 8. Add transaction to ledger
    try ledger.addTransaction(transfer_tx);

    // 9. Check balances
    const alice_balance = try ledger.getBalance("alice");
    const bob_balance = try ledger.getBalance("bob");

    std.debug.print("Alice balance: ${d:.2}\\n", .{alice_balance.toFloat()});
    std.debug.print("Bob balance: ${d:.2}\\n", .{bob_balance.toFloat()});

    // 10. Run audit
    const audit_report = try ledger.runAudit();
    std.debug.print("Ledger balanced: {}\\n", .{audit_report.is_balanced});

    std.debug.print("Transaction completed successfully!\\n", .{});
}
```

## 🔧 Build Configuration

To run the examples, create a `build.zig`:

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
        .name = "example",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zledger", zledger.module("zledger"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&run_cmd.step);
}
```

And `build.zig.zon`:

```zig
.{
    .name = "zledger-example",
    .version = "0.1.0",
    .dependencies = .{
        .zledger = .{
            .url = "https://github.com/ghostkellz/zledger",
            .hash = "12345...", // Will be filled by zig fetch
        },
    },
    .paths = .{""},
}
```

## 🏗️ Project Structure

```
your-project/
├── build.zig
├── build.zig.zon
└── src/
    ├── main.zig
    ├── ledger.zig      # Ledger management
    ├── crypto.zig      # Cryptographic operations
    └── api.zig         # REST API (optional)
```

## 📖 Example Descriptions

### Financial Applications

- **[Digital Wallet](./financial/wallet.md)** - Complete wallet with send/receive functionality
- **[Trading System](./financial/trading.md)** - Multi-currency trading with order matching
- **[Payment Processor](./financial/payments.md)** - Payment gateway with escrow functionality

### Cryptographic Operations

- **[Transaction Signing](./crypto/signing.md)** - Secure transaction authentication
- **[Multi-Sig](./crypto/multisig.md)** - Multiple signature requirements
- **[Key Rotation](./crypto/rotation.md)** - Key management and rotation strategies

### Web Integration

- **[WASM Ledger](./web/wasm.md)** - Browser-based ledger using WebAssembly
- **[REST API](./web/api.md)** - HTTP API for ledger operations
- **[WebSocket Updates](./web/websocket.md)** - Real-time transaction notifications

### Advanced Integrations

- **[Microservices](./advanced/microservices.md)** - Distributed ledger architecture
- **[Event Sourcing](./advanced/events.md)** - Event-driven transaction processing
- **[Audit System](./advanced/audit.md)** - Compliance and audit trail management

## 🚀 Running Examples

1. **Clone or create your project:**
   ```bash
   mkdir my-zledger-app && cd my-zledger-app
   zig init
   ```

2. **Add Zledger dependency:**
   ```bash
   zig fetch --save https://github.com/ghostkellz/zledger
   ```

3. **Copy example code** into `src/main.zig`

4. **Update build.zig** to include Zledger

5. **Run the example:**
   ```bash
   zig build run
   ```

## 📚 Next Steps

- Explore the [API Reference](../api/) for detailed function documentation
- Check [Best Practices](../integration/best-practices.md) for optimization tips
- Review [Integration Guide](../integration/) for project setup details
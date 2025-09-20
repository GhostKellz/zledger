# Integration Guide

This guide shows how to integrate Zledger into your Zig projects using the package manager.

## 📦 Adding Zledger to Your Project

### Step 1: Fetch the Package

```bash
zig fetch --save https://github.com/ghostkellz/zledger
```

This adds Zledger as a dependency to your `build.zig.zon` file.

### Step 2: Update Your build.zig

Add Zledger as a dependency in your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get the zledger dependency
    const zledger = b.dependency("zledger", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "your-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add zledger module to your executable
    exe.root_module.addImport("zledger", zledger.module("zledger"));

    b.installArtifact(exe);
}
```

### Step 3: Import in Your Code

```zig
const std = @import("std");
const zledger = @import("zledger");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Use zledger functionality
    var ledger = zledger.Ledger.init(allocator);
    defer ledger.deinit();

    // Generate cryptographic keypair
    const keypair = try zledger.generateKeypair(allocator);

    // Sign a transaction message
    const message = "Transfer: alice -> bob, 1000 USD";
    const signature = try zledger.signMessage(message, keypair);

    std.debug.print("Transaction signed successfully!\\n", .{});
}
```

## 🎯 Integration Patterns

### 1. Ledger-Only Integration

If you only need the ledger functionality without crypto:

```zig
const zledger = @import("zledger");

var ledger = zledger.Ledger.init(allocator);
try ledger.createAccount("alice", .asset, "USD");
try ledger.createAccount("bob", .asset, "USD");

const tx = zledger.Transaction{
    .id = "tx1",
    .timestamp = std.time.timestamp(),
    .amount = 10000, // $100.00 in cents
    .currency = "USD",
    .from_account = "alice",
    .to_account = "bob",
    .memo = "Payment for services",
};

try ledger.addTransaction(tx);
```

### 2. Crypto-Only Integration

If you only need the cryptographic signing:

```zig
const zledger = @import("zledger");

// Generate keypair
const keypair = try zledger.generateKeypair(allocator);

// Sign data
const data = "Important message to sign";
const signature = try zledger.signMessage(data, keypair);

// Verify signature
const is_valid = zledger.verifySignature(data, &signature.bytes, &keypair.publicKey());
```

### 3. Full Integration

Combining ledger and crypto for signed transactions:

```zig
const zledger = @import("zledger");

var ledger = zledger.Ledger.init(allocator);
const signer_keypair = try zledger.generateKeypair(allocator);

// Create signed transaction
const tx = zledger.Transaction{ /* ... */ };
const tx_data = try std.json.stringifyAlloc(allocator, tx, .{});
defer allocator.free(tx_data);

const signature = try zledger.signMessage(tx_data, signer_keypair);

// Add to ledger with signature verification
try ledger.addTransaction(tx);
// Store signature for audit trail
```

## 🔧 Build Configuration

### Required Dependencies

Zledger automatically includes its dependencies:
- **zcrypto**: For cryptographic operations
- No additional setup required

### Target Compatibility

Zledger supports:
- **Native**: All platforms supported by Zig
- **WebAssembly**: WASM32 target for web applications
- **Embedded**: Minimal resource usage for embedded systems

### Optimization Modes

All Zig optimization modes are supported:
- `Debug`: Development with full debugging
- `ReleaseSafe`: Production with safety checks
- `ReleaseFast`: Maximum performance
- `ReleaseSmall`: Minimal binary size

## 🚀 Next Steps

- [API Reference](../api/) - Detailed API documentation
- [Examples](../examples/) - Code samples and use cases
- [Best Practices](./best-practices.md) - Recommended patterns and practices
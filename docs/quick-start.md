# Quick Start Guide

Get up and running with Zledger in minutes.

## Installation

### As a Zig Dependency

1. Add Zledger to your project:
```bash
zig fetch --save https://github.com/ghostkellz/zledger/archive/refs/heads/main.tar.gz
```

2. Update your `build.zig`:
```zig
const zledger = b.dependency("zledger", .{});
exe.root_module.addImport("zledger", zledger.module("zledger"));
```

### Building from Source

```bash
git clone https://github.com/ghostkellz/zledger
cd zledger
zig build
```

## Basic Usage

### Simple Ledger Operations

```zig
const std = @import("std");
const zledger = @import("zledger");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a new ledger
    var ledger = zledger.Ledger.init(allocator);
    defer ledger.deinit();

    // Create accounts
    const cash_account = try ledger.createAccount(.{
        .name = "Cash",
        .account_type = .Assets,
    });

    const revenue_account = try ledger.createAccount(.{
        .name = "Sales Revenue",
        .account_type = .Revenue,
    });

    // Create a transaction
    var transaction = zledger.Transaction.init(allocator);
    defer transaction.deinit();

    // Add transaction entries (double-entry bookkeeping)
    try transaction.addEntry(.{
        .account_id = cash_account,
        .amount = zledger.FixedPoint.fromFloat(1000.00),
        .debit = true,
    });

    try transaction.addEntry(.{
        .account_id = revenue_account,
        .amount = zledger.FixedPoint.fromFloat(1000.00),
        .debit = false,
    });

    // Post transaction to ledger
    try ledger.postTransaction(&transaction);
}
```

### Cryptographic Signing

```zig
const std = @import("std");
const zledger = @import("zledger");

pub fn main() !void {
    // Generate a keypair
    const keypair = try zledger.generateKeypair();

    // Sign a message
    const message = "Hello, Zledger!";
    const signature = try zledger.signMessage(keypair, message);

    // Verify the signature
    const is_valid = try zledger.verifySignature(
        keypair.public_key,
        message,
        signature
    );

    std.debug.print("Signature valid: {}\n", .{is_valid});
}
```

### Smart Contracts

```zig
const std = @import("std");
const zledger = @import("zledger");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a simple contract
    var contract = zledger.Contract.init(allocator, .{
        .gas_limit = 1000000,
        .initial_state = &.{},
    });
    defer contract.deinit();

    // Execute contract function
    const result = try contract.execute("transfer", &.{
        .{ .address = "0x123...", .amount = 100 },
    });

    std.debug.print("Contract result: {}\n", .{result});
}
```

## CLI Usage

Zledger comes with a command-line interface:

```bash
# Build the CLI
zig build

# Create a new ledger
./zig-out/bin/zledger create-ledger mycompany.ledger

# Add an account
./zig-out/bin/zledger add-account --name "Cash" --type Assets

# Create a transaction
./zig-out/bin/zledger add-transaction --description "Initial deposit" \
  --debit Cash:1000.00 --credit "Owner Equity":1000.00

# Generate audit report
./zig-out/bin/zledger audit-report --format json

# Generate a keypair
./zig-out/bin/zledger generate-keys --output keys.json

# Sign a file
./zig-out/bin/zledger sign --key keys.json --file document.pdf
```

## Configuration Options

Build with specific features:

```bash
# Minimal ledger build
zig build -Dledger=true -Dzsig=false -Dcontracts=false

# Crypto-only build
zig build -Dledger=false -Dzsig=true -Dcrypto-storage=true

# Full-featured build
zig build
```

## Next Steps

- Read the [Build Configuration](build-configuration.md) guide
- Explore the [Examples](../examples/) directory
- Check the [API Reference](core-ledger.md)
- Learn about [Smart Contracts](smart-contracts.md)
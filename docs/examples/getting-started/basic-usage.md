# Basic Usage Example

This example demonstrates the fundamental operations of Zledger v0.5.0, including ledger setup, account creation, transaction processing, and cryptographic signing.

## Project Setup

### 1. Initialize Project

```bash
mkdir my-ledger-app && cd my-ledger-app
zig init
```

### 2. Add Zledger v0.5.0

```bash
zig fetch --save https://github.com/ghostkellz/zledger
```

### 3. Configure build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add Zledger v0.5.0 dependency
    const zledger = b.dependency("zledger", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "my-ledger-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Import Zledger module
    exe.root_module.addImport("zledger", zledger.module("zledger"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
```

## Complete Example

### src/main.zig

```zig
const std = @import("std");
const zledger = @import("zledger");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🚀 Zledger v0.5.0 Basic Example\\n\\n", .{});

    // ========================================
    // 1. Initialize Ledger System
    // ========================================
    std.debug.print("📊 Initializing ledger...\\n", .{});

    var ledger = zledger.Ledger.init(allocator);
    defer ledger.deinit();

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

    // ========================================
    // 2. Create Accounts
    // ========================================
    std.debug.print("👥 Creating accounts...\\n", .{});

    // Create user accounts
    try ledger.createAccount("alice", .asset, "USD");
    try ledger.createAccount("bob", .asset, "USD");
    try ledger.createAccount("charlie", .asset, "USD");

    // Create system accounts
    try ledger.createAccount("bank_reserves", .asset, "USD");
    try ledger.createAccount("fee_income", .revenue, "USD");

    std.debug.print("   ✓ Created 5 accounts\\n", .{});

    // ========================================
    // 3. Generate Cryptographic Keys
    // ========================================
    std.debug.print("🔐 Generating signing keys...\\n", .{});

    const bank_keypair = try zledger.generateKeypair(allocator);
    const alice_keypair = try zledger.generateKeypair(allocator);

    // Export public keys for display
    const bank_pubkey = try bank_keypair.publicKeyHex(allocator);
    defer allocator.free(bank_pubkey);

    const alice_pubkey = try alice_keypair.publicKeyHex(allocator);
    defer allocator.free(alice_pubkey);

    std.debug.print("   ✓ Bank public key: {}...\\n", .{std.fmt.fmtSliceHexLower(bank_pubkey[0..16])});
    std.debug.print("   ✓ Alice public key: {}...\\n", .{std.fmt.fmtSliceHexLower(alice_pubkey[0..16])});

    // ========================================
    // 4. Fund Accounts (Signed Transactions)
    // ========================================
    std.debug.print("💰 Funding accounts with signed transactions...\\n", .{});

    // Fund Alice's account from bank reserves
    const funding_tx = zledger.Transaction{
        .id = "FUND-001",
        .timestamp = std.time.timestamp(),
        .amount = 500000, // $5000.00 in cents
        .currency = "USD",
        .from_account = "bank_reserves",
        .to_account = "alice",
        .memo = "Initial account funding",
    };

    // Sign the funding transaction
    const funding_json = try std.json.stringifyAlloc(allocator, funding_tx, .{});
    defer allocator.free(funding_json);

    const funding_signature = try zledger.signMessage(funding_json, bank_keypair);

    // Verify signature before processing
    if (!zledger.verifySignature(funding_json, &funding_signature.bytes, &bank_keypair.publicKey())) {
        std.debug.print("❌ Funding transaction signature verification failed!\\n", .{});
        return;
    }

    try ledger.addTransaction(funding_tx);
    std.debug.print("   ✓ Funded Alice with $5000.00\\n", .{});

    // ========================================
    // 5. Process User Transactions
    // ========================================
    std.debug.print("🔄 Processing user transactions...\\n", .{});

    // Alice sends money to Bob
    const transfer_tx = zledger.Transaction{
        .id = "TXN-001",
        .timestamp = std.time.timestamp(),
        .amount = 150000, // $1500.00 in cents
        .currency = "USD",
        .from_account = "alice",
        .to_account = "bob",
        .memo = "Payment for consulting services",
    };

    // Sign transaction with Alice's key
    const transfer_json = try std.json.stringifyAlloc(allocator, transfer_tx, .{});
    defer allocator.free(transfer_json);

    const transfer_signature = try zledger.signMessage(transfer_json, alice_keypair);

    // Verify Alice's signature
    if (!zledger.verifySignature(transfer_json, &transfer_signature.bytes, &alice_keypair.publicKey())) {
        std.debug.print("❌ Transfer transaction signature verification failed!\\n", .{});
        return;
    }

    try ledger.addTransaction(transfer_tx);
    std.debug.print("   ✓ Alice sent $1500.00 to Bob\\n", .{});

    // Processing fee transaction
    const fee_tx = zledger.Transaction{
        .id = "FEE-001",
        .timestamp = std.time.timestamp(),
        .amount = 500, // $5.00 fee
        .currency = "USD",
        .from_account = "alice",
        .to_account = "fee_income",
        .memo = "Transaction processing fee",
    };

    try ledger.addTransaction(fee_tx);
    std.debug.print("   ✓ Processed $5.00 transaction fee\\n", .{});

    // ========================================
    // 6. Check Account Balances
    // ========================================
    std.debug.print("📈 Current account balances:\\n", .{});

    const alice_balance = try ledger.getBalance("alice");
    const bob_balance = try ledger.getBalance("bob");
    const fee_balance = try ledger.getBalance("fee_income");

    std.debug.print("   💳 Alice: ${d:.2}\\n", .{alice_balance.toFloat()});
    std.debug.print("   💳 Bob: ${d:.2}\\n", .{bob_balance.toFloat()});
    std.debug.print("   💳 Fee Income: ${d:.2}\\n", .{fee_balance.toFloat()});

    // ========================================
    // 7. Demonstrate Batch Signing
    // ========================================
    std.debug.print("🔏 Demonstrating batch cryptographic operations...\\n", .{});

    // Create multiple transaction messages
    const batch_messages = [_][]const u8{
        "Transaction batch item 1",
        "Transaction batch item 2",
        "Transaction batch item 3",
    };

    // Sign all messages in one operation
    const batch_signatures = try zledger.zsig.signBatch(allocator, &batch_messages, alice_keypair);
    defer allocator.free(batch_signatures);

    // Verify all signatures
    const all_valid = zledger.zsig.verify.verifyBatchSameKey(
        &batch_messages,
        batch_signatures,
        alice_keypair.publicKey()
    );

    std.debug.print("   ✓ Batch signed and verified {} messages: {}\\n", .{ batch_messages.len, all_valid });

    // ========================================
    // 8. Run Audit and Integrity Checks
    // ========================================
    std.debug.print("🔍 Running ledger audit...\\n", .{});

    const audit_report = try ledger.runAudit();

    std.debug.print("   📋 Audit Results:\\n", .{});
    std.debug.print("      • Ledger balanced: {}\\n", .{audit_report.is_balanced});
    std.debug.print("      • Total transactions: {}\\n", .{audit_report.total_transactions});
    std.debug.print("      • Total accounts: {}\\n", .{audit_report.total_accounts});

    if (audit_report.is_balanced) {
        std.debug.print("   ✅ Ledger integrity verified!\\n", .{});
    } else {
        std.debug.print("   ❌ Ledger integrity check failed!\\n", .{});
    }

    // ========================================
    // 9. Export Transaction History
    // ========================================
    std.debug.print("📤 Exporting transaction history...\\n", .{});

    // Create journal for transaction logging
    var journal = zledger.Journal.init(allocator, "transaction_history.json");
    defer journal.deinit();

    // Add all transactions to journal with signatures
    const transactions = [_]zledger.Transaction{ funding_tx, transfer_tx, fee_tx };
    const signatures = [_]zledger.Signature{ funding_signature, transfer_signature, funding_signature }; // Reusing signature for demo

    for (transactions, signatures) |tx, sig| {
        const entry = zledger.JournalEntry{
            .transaction = tx,
            .timestamp = std.time.timestamp(),
            .signature = sig,
        };
        try journal.addEntry(entry);
    }

    try journal.saveToFile("transaction_history.json");
    std.debug.print("   ✓ Exported {} transactions to transaction_history.json\\n", .{transactions.len});

    // ========================================
    // 10. Summary
    // ========================================
    std.debug.print("\\n🎉 Zledger v0.5.0 Demo Complete!\\n", .{});
    std.debug.print("\\nFeatures demonstrated:\\n", .{});
    std.debug.print("  ✓ Double-entry ledger accounting\\n", .{});
    std.debug.print("  ✓ Ed25519 cryptographic signing\\n", .{});
    std.debug.print("  ✓ Transaction verification\\n", .{});
    std.debug.print("  ✓ Batch signature operations\\n", .{});
    std.debug.print("  ✓ Audit trail and integrity checks\\n", .{});
    std.debug.print("  ✓ Multi-currency asset support\\n", .{});
    std.debug.print("  ✓ Persistent transaction journaling\\n", .{});

    std.debug.print("\\n📚 Next steps:\\n", .{});
    std.debug.print("  • Explore the API documentation\\n", .{});
    std.debug.print("  • Try the advanced examples\\n", .{});
    std.debug.print("  • Integrate into your application\\n", .{});
}
```

## Running the Example

```bash
# Build and run
zig build run

# Expected output:
🚀 Zledger v0.5.0 Basic Example

📊 Initializing ledger...
👥 Creating accounts...
   ✓ Created 5 accounts
🔐 Generating signing keys...
   ✓ Bank public key: a1b2c3d4e5f6g7h8...
   ✓ Alice public key: 9i8j7k6l5m4n3o2p...
💰 Funding accounts with signed transactions...
   ✓ Funded Alice with $5000.00
🔄 Processing user transactions...
   ✓ Alice sent $1500.00 to Bob
   ✓ Processed $5.00 transaction fee
📈 Current account balances:
   💳 Alice: $3495.00
   💳 Bob: $1500.00
   💳 Fee Income: $5.00
🔏 Demonstrating batch cryptographic operations...
   ✓ Batch signed and verified 3 messages: true
🔍 Running ledger audit...
   📋 Audit Results:
      • Ledger balanced: true
      • Total transactions: 3
      • Total accounts: 5
   ✅ Ledger integrity verified!
📤 Exporting transaction history...
   ✓ Exported 3 transactions to transaction_history.json

🎉 Zledger v0.5.0 Demo Complete!
```

## Key Features Showcased

1. **Ledger Management** - Account creation, balance tracking
2. **Cryptographic Security** - Ed25519 signing and verification
3. **Transaction Processing** - Signed, verified transactions
4. **Batch Operations** - Efficient bulk signing/verification
5. **Audit Capabilities** - Integrity checks and reporting
6. **Asset Support** - Multi-currency functionality
7. **Persistent Storage** - Transaction journaling and export

## Next Steps

- Explore [Financial Examples](../financial/) for real-world applications
- Learn about [Advanced Cryptographic Operations](../crypto/)
- Check out [Web Integration Examples](../web/) for browser usage
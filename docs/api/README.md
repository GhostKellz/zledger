# API Reference

Complete API documentation for Zledger's ledger and cryptographic functionality.

## 📚 Module Overview

### Core Modules
- [**Ledger**](./ledger.md) - Account management and transaction processing
- [**Transaction**](./transaction.md) - Transaction creation and management
- [**Audit**](./audit.md) - Ledger integrity and audit trail verification
- [**Journal**](./journal.md) - Persistent transaction logging

### Cryptographic Modules
- [**Zsig**](./zsig.md) - Cryptographic signing and verification
- [**Keypair**](./keypair.md) - Key generation and management
- [**Signature**](./signature.md) - Digital signature operations

### Utility Modules
- [**FixedPoint**](./fixed-point.md) - Precision arithmetic for financial calculations
- [**Asset**](./asset.md) - Multi-currency and asset management

## 🚀 Quick Reference

### Basic Ledger Operations

```zig
const zledger = @import("zledger");

// Initialize ledger
var ledger = zledger.Ledger.init(allocator);
defer ledger.deinit();

// Create accounts
try ledger.createAccount("alice", .asset, "USD");
try ledger.createAccount("bob", .asset, "USD");

// Create transaction
const tx = zledger.Transaction{
    .id = "tx1",
    .timestamp = std.time.timestamp(),
    .amount = 10000, // $100.00 in cents
    .currency = "USD",
    .from_account = "alice",
    .to_account = "bob",
    .memo = "Payment",
};

// Add to ledger
try ledger.addTransaction(tx);

// Check balance
const balance = try ledger.getBalance("alice");
```

### Cryptographic Operations

```zig
// Generate keypair
const keypair = try zledger.generateKeypair(allocator);

// Sign message
const message = "Important data to sign";
const signature = try zledger.signMessage(message, keypair);

// Verify signature
const is_valid = zledger.verifySignature(message, &signature.bytes, &keypair.publicKey());

// Export keys
const public_hex = try keypair.publicKeyHex(allocator);
defer allocator.free(public_hex);

const key_bundle = try keypair.exportBundle(allocator);
defer allocator.free(key_bundle);
```

## 🔧 Error Handling

### Common Error Types

```zig
// Ledger errors
const LedgerError = error{
    AccountNotFound,
    InsufficientFunds,
    InvalidCurrency,
    DuplicateAccount,
};

// Crypto errors
const CryptoError = error{
    InvalidSignature,
    KeyGenerationFailed,
    InvalidKeyFormat,
};

// Usage
ledger.addTransaction(tx) catch |err| switch (err) {
    LedgerError.AccountNotFound => {
        std.debug.print("Account does not exist\\n", .{});
    },
    LedgerError.InsufficientFunds => {
        std.debug.print("Not enough balance\\n", .{});
    },
    else => return err,
};
```

## 📊 Data Structures

### Core Types

```zig
// Transaction representation
pub const Transaction = struct {
    id: []const u8,
    timestamp: i64,
    amount: i64,           // In smallest currency unit (cents)
    currency: []const u8,
    from_account: []const u8,
    to_account: []const u8,
    memo: ?[]const u8,
};

// Account types
pub const AccountType = enum {
    asset,      // Assets (cash, receivables)
    liability,  // Liabilities (payables, loans)
    equity,     // Owner's equity
    revenue,    // Income/revenue
    expense,    // Expenses/costs
};

// Signature structure
pub const Signature = struct {
    bytes: [64]u8,

    pub fn toHex(self: Signature, allocator: std.mem.Allocator) ![]u8;
    pub fn fromHex(hex: []const u8) !Signature;
};
```

### Precision Types

```zig
// Fixed-point arithmetic
pub const FixedPoint = struct {
    value: i64,

    pub fn fromFloat(f: f64) FixedPoint;
    pub fn fromCents(cents: i64) FixedPoint;
    pub fn toFloat(self: FixedPoint) f64;
    pub fn add(self: FixedPoint, other: FixedPoint) FixedPoint;
    pub fn subtract(self: FixedPoint, other: FixedPoint) FixedPoint;
    pub fn multiply(self: FixedPoint, other: FixedPoint) FixedPoint;
};
```

## 🔐 Security Considerations

### Key Management

- **Never log private keys** - Use secure storage mechanisms
- **Use deterministic generation** - For reproducible audit trails
- **Verify all signatures** - Before processing transactions
- **Rotate keys regularly** - Following security best practices

### Transaction Security

- **Sign complete data** - Include all transaction fields
- **Use unique IDs** - Prevent replay attacks
- **Validate inputs** - Check account existence and balances
- **Maintain audit trails** - For compliance and debugging

## 📈 Performance Notes

### Memory Usage

- **Use arena allocators** - For batch operations
- **Free resources** - Always defer cleanup
- **Reuse keypairs** - Avoid repeated generation

### Batch Operations

- **Sign multiple messages** - Use batch signing APIs
- **Process transactions** - In groups for efficiency
- **Verify signatures** - Batch verification when possible

## 🔗 See Also

- [Integration Guide](../integration/) - How to add Zledger to your project
- [Examples](../examples/) - Practical usage examples
- [Best Practices](../integration/best-practices.md) - Recommended patterns
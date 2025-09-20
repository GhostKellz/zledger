# Best Practices

This guide covers recommended patterns and practices for using Zledger effectively.

## 🔐 Security Best Practices

### Keypair Management

**✅ DO:**
```zig
// Use deterministic generation for reproducible keys
const seed = [_]u8{42} ** 32; // From secure source
const keypair = zledger.zsig.keypairFromSeed(seed);

// Store private keys securely
const bundle = try keypair.exportBundle(allocator);
// Save to secure file with proper permissions
```

**❌ DON'T:**
```zig
// Don't log private keys
std.debug.print("Private key: {}", .{keypair.secretKey()}); // NEVER DO THIS

// Don't use weak seeds
const weak_seed = [_]u8{1} ** 32; // Predictable!
```

### Transaction Signing

**✅ DO:**
```zig
// Sign the complete transaction data
const tx_json = try std.json.stringifyAlloc(allocator, transaction, .{});
defer allocator.free(tx_json);
const signature = try zledger.signMessage(tx_json, keypair);

// Verify before processing
if (!zledger.verifySignature(tx_json, &signature.bytes, &public_key)) {
    return error.InvalidSignature;
}
```

## 💰 Financial Precision

### Fixed-Point Arithmetic

**✅ DO:**
```zig
// Use FixedPoint for all monetary values
const amount = zledger.FixedPoint.fromFloat(100.50); // $100.50
const tax = amount.multiply(zledger.FixedPoint.fromFloat(0.08)); // 8% tax
const total = amount.add(tax);
```

**❌ DON'T:**
```zig
// Never use floating point for money
const amount: f64 = 100.50; // Precision errors!
const tax = amount * 0.08; // Rounding issues!
```

### Currency Handling

**✅ DO:**
```zig
// Always specify currency explicitly
try ledger.createAccount("alice", .asset, "USD");
try ledger.createAccount("alice_eur", .asset, "EUR");

// Separate accounts for different currencies
const tx_usd = zledger.Transaction{
    .currency = "USD",
    .amount = 10000, // $100.00 in cents
    // ...
};
```

## 🗃️ Ledger Architecture

### Account Organization

**✅ DO:**
```zig
// Use descriptive account names with prefixes
try ledger.createAccount("user:alice:checking", .asset, "USD");
try ledger.createAccount("user:alice:savings", .asset, "USD");
try ledger.createAccount("fee:transaction", .revenue, "USD");
try ledger.createAccount("liability:user_deposits", .liability, "USD");
```

### Transaction Patterns

**✅ DO:**
```zig
// Always use double-entry accounting
const deposit_tx = zledger.Transaction{
    .from_account = "bank:reserves",
    .to_account = "user:alice:checking",
    .amount = 50000, // $500.00
    // ...
};

// Create offsetting liability
const liability_tx = zledger.Transaction{
    .from_account = "user:alice:checking",
    .to_account = "liability:user_deposits",
    .amount = 50000,
    // ...
};
```

## 🔍 Error Handling

### Graceful Degradation

**✅ DO:**
```zig
const TransactionError = error{
    InsufficientFunds,
    InvalidAccount,
    SignatureVerificationFailed,
};

fn processTransaction(ledger: *zledger.Ledger, tx: zledger.Transaction) TransactionError!void {
    // Validate before processing
    const from_balance = ledger.getBalance(tx.from_account) catch return TransactionError.InvalidAccount;
    if (from_balance.lessThan(zledger.FixedPoint.fromCents(tx.amount))) {
        return TransactionError.InsufficientFunds;
    }

    // Process transaction
    ledger.addTransaction(tx) catch |err| switch (err) {
        error.AccountNotFound => return TransactionError.InvalidAccount,
        else => return err,
    };
}
```

### Audit Trail Maintenance

**✅ DO:**
```zig
// Always maintain complete audit trails
var journal = zledger.Journal.init(allocator, "transactions.journal");

// Add transactions with metadata
const entry = zledger.JournalEntry{
    .transaction = tx,
    .timestamp = std.time.timestamp(),
    .signature = signature,
    .metadata = .{
        .source = "api",
        .user_agent = "MyApp/1.0",
        .ip_address = "192.168.1.100",
    },
};

try journal.addEntry(entry);
```

## 🚀 Performance Optimization

### Memory Management

**✅ DO:**
```zig
// Use arena allocators for transaction batches
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
const arena_allocator = arena.allocator();

// Process batch
for (transaction_batch) |tx| {
    const signature = try zledger.signMessage(tx_data, keypair);
    // Arena will clean up all allocations at once
}
```

### Batch Operations

**✅ DO:**
```zig
// Use batch signing for multiple transactions
const messages = [_][]const u8{ tx1_data, tx2_data, tx3_data };
const signatures = try zledger.zsig.signBatch(allocator, &messages, keypair);
defer allocator.free(signatures);

// Batch verification
const is_valid = zledger.zsig.verify.verifyBatchSameKey(&messages, signatures, keypair.publicKey());
```

## 🔄 Integration Patterns

### Microservices Architecture

**✅ DO:**
```zig
// Expose Zledger through clean interfaces
const LedgerService = struct {
    ledger: zledger.Ledger,
    signer: zledger.Keypair,

    pub fn transfer(self: *Self, from: []const u8, to: []const u8, amount: i64) ![]const u8 {
        const tx = zledger.Transaction{
            .from_account = from,
            .to_account = to,
            .amount = amount,
            // ...
        };

        const tx_data = try std.json.stringifyAlloc(self.allocator, tx, .{});
        const signature = try zledger.signMessage(tx_data, self.signer);

        try self.ledger.addTransaction(tx);
        return tx.id;
    }
};
```

### Event-Driven Systems

**✅ DO:**
```zig
// Emit events for transaction lifecycle
const TransactionEvent = union(enum) {
    created: zledger.Transaction,
    signed: struct { id: []const u8, signature: zledger.Signature },
    completed: []const u8,
    failed: struct { id: []const u8, error: []const u8 },
};

fn emitEvent(event: TransactionEvent) void {
    // Send to event bus, log, or notify subscribers
}
```

## 📊 Monitoring and Observability

### Metrics Collection

**✅ DO:**
```zig
// Track important metrics
const Metrics = struct {
    transactions_processed: u64 = 0,
    signatures_verified: u64 = 0,
    errors_encountered: u64 = 0,

    pub fn incrementTransactions(self: *Self) void {
        self.transactions_processed += 1;
    }
};

// Use in transaction processing
metrics.incrementTransactions();
```

### Health Checks

**✅ DO:**
```zig
pub fn healthCheck(ledger: *zledger.Ledger) !bool {
    // Verify ledger integrity
    const audit_report = try ledger.runAudit();
    if (!audit_report.is_balanced) return false;

    // Test crypto functionality
    const test_keypair = try zledger.generateKeypair(allocator);
    const test_sig = try zledger.signMessage("health_check", test_keypair);
    if (!zledger.verifySignature("health_check", &test_sig.bytes, &test_keypair.publicKey())) {
        return false;
    }

    return true;
}
```
# Ledger API Reference

The Ledger module provides double-entry accounting functionality with account management and transaction processing.

## 🏗️ Core Structure

```zig
pub const Ledger = struct {
    accounts: AccountManager,
    asset_registry: AssetRegistry,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Ledger;
    pub fn deinit(self: *Ledger) void;
    // ... methods
};
```

## 📊 Account Management

### `createAccount(name: []const u8, account_type: AccountType, currency: []const u8) !void`

Creates a new account with the specified type and currency.

```zig
var ledger = zledger.Ledger.init(allocator);
defer ledger.deinit();

// Create different account types
try ledger.createAccount("cash", .asset, "USD");
try ledger.createAccount("accounts_payable", .liability, "USD");
try ledger.createAccount("revenue", .revenue, "USD");
try ledger.createAccount("expenses", .expense, "USD");
try ledger.createAccount("owners_equity", .equity, "USD");
```

**Account Types:**
- `asset` - Cash, receivables, inventory
- `liability` - Payables, loans, deposits
- `equity` - Owner's equity, retained earnings
- `revenue` - Income, sales revenue
- `expense` - Operating costs, fees

### `getBalance(account_name: []const u8) !FixedPoint`

Returns the current balance for an account.

```zig
const balance = try ledger.getBalance("cash");
std.debug.print("Cash balance: ${d:.2}\\n", .{balance.toFloat()});
```

### `listAccounts() ![]Account`

Returns all accounts in the ledger.

```zig
const accounts = try ledger.listAccounts();
for (accounts) |account| {
    const balance = try ledger.getBalance(account.name);
    std.debug.print("{s}: ${d:.2}\\n", .{ account.name, balance.toFloat() });
}
```

## 💸 Transaction Processing

### `addTransaction(transaction: Transaction) !void`

Adds a transaction to the ledger using double-entry accounting.

```zig
const tx = zledger.Transaction{
    .id = "TXN-001",
    .timestamp = std.time.timestamp(),
    .amount = 50000, // $500.00 in cents
    .currency = "USD",
    .from_account = "cash",
    .to_account = "revenue",
    .memo = "Sales income",
};

try ledger.addTransaction(tx);
```

**Double-Entry Rules:**
- Assets increase with debits, decrease with credits
- Liabilities increase with credits, decrease with debits
- Equity increases with credits, decrease with debits
- Revenue increases with credits
- Expenses increase with debits

### `getTransactionHistory(account_name: []const u8) ![]Transaction`

Returns all transactions for a specific account.

```zig
const history = try ledger.getTransactionHistory("cash");
for (history) |tx| {
    std.debug.print("Transaction {s}: {s} -> {s}, ${d:.2}\\n", .{
        tx.id, tx.from_account, tx.to_account, @as(f64, @floatFromInt(tx.amount)) / 100.0
    });
}
```

## 🔍 Audit and Verification

### `runAudit() !AuditReport`

Performs comprehensive ledger integrity checks.

```zig
const audit_report = try ledger.runAudit();

std.debug.print("Audit Results:\\n", .{});
std.debug.print("  Balanced: {}\\n", .{audit_report.is_balanced});
std.debug.print("  Total Transactions: {}\\n", .{audit_report.total_transactions});
std.debug.print("  Total Accounts: {}\\n", .{audit_report.total_accounts});

if (audit_report.discrepancies.len > 0) {
    std.debug.print("  Discrepancies found:\\n", .{});
    for (audit_report.discrepancies) |disc| {
        std.debug.print("    {s}: ${d:.2}\\n", .{ disc.account, disc.amount });
    }
}
```

### `verifyTransaction(transaction: Transaction) !bool`

Verifies a transaction's validity without adding it to the ledger.

```zig
const tx = zledger.Transaction{ /* ... */ };
const is_valid = try ledger.verifyTransaction(tx);

if (is_valid) {
    try ledger.addTransaction(tx);
} else {
    std.debug.print("Transaction validation failed\\n", .{});
}
```

## 💱 Multi-Currency Support

### Asset Registration

```zig
// Register currencies/assets
const usd_asset = zledger.Asset{
    .id = "USD",
    .metadata = .{
        .symbol = "USD",
        .name = "US Dollar",
        .decimals = 2,
    },
};

const btc_asset = zledger.Asset{
    .id = "BTC",
    .metadata = .{
        .symbol = "BTC",
        .name = "Bitcoin",
        .decimals = 8, // Bitcoin has 8 decimal places
    },
};

try ledger.asset_registry.registerAsset(usd_asset);
try ledger.asset_registry.registerAsset(btc_asset);
```

### Multi-Currency Accounts

```zig
// Create accounts for different currencies
try ledger.createAccount("cash_usd", .asset, "USD");
try ledger.createAccount("cash_btc", .asset, "BTC");
try ledger.createAccount("cash_eur", .asset, "EUR");

// Transfer between different currency accounts
const exchange_tx = zledger.Transaction{
    .id = "EXCHANGE-001",
    .amount = 100000000, // 1.0 BTC in satoshis
    .currency = "BTC",
    .from_account = "cash_btc",
    .to_account = "exchange_btc",
    .memo = "Bitcoin to exchange",
};

try ledger.addTransaction(exchange_tx);
```

## 📈 Balance Sheet Generation

### `generateBalanceSheet() !BalanceSheet`

Creates a complete balance sheet showing assets, liabilities, and equity.

```zig
const balance_sheet = try ledger.generateBalanceSheet();

std.debug.print("BALANCE SHEET\\n", .{});
std.debug.print("=============\\n", .{});

std.debug.print("ASSETS:\\n", .{});
for (balance_sheet.assets) |asset| {
    std.debug.print("  {s}: ${d:.2}\\n", .{ asset.name, asset.balance.toFloat() });
}
std.debug.print("Total Assets: ${d:.2}\\n\\n", .{balance_sheet.total_assets.toFloat()});

std.debug.print("LIABILITIES:\\n", .{});
for (balance_sheet.liabilities) |liability| {
    std.debug.print("  {s}: ${d:.2}\\n", .{ liability.name, liability.balance.toFloat() });
}
std.debug.print("Total Liabilities: ${d:.2}\\n\\n", .{balance_sheet.total_liabilities.toFloat()});

std.debug.print("EQUITY:\\n", .{});
for (balance_sheet.equity) |equity| {
    std.debug.print("  {s}: ${d:.2}\\n", .{ equity.name, equity.balance.toFloat() });
}
std.debug.print("Total Equity: ${d:.2}\\n", .{balance_sheet.total_equity.toFloat()});
```

## 🔄 Batch Operations

### `addTransactionBatch(transactions: []const Transaction) !void`

Efficiently processes multiple transactions.

```zig
const transactions = [_]zledger.Transaction{
    .{ .id = "BATCH-001", .amount = 10000, .from_account = "cash", .to_account = "revenue", /* ... */ },
    .{ .id = "BATCH-002", .amount = 5000, .from_account = "cash", .to_account = "revenue", /* ... */ },
    .{ .id = "BATCH-003", .amount = 2000, .from_account = "expenses", .to_account = "cash", /* ... */ },
};

try ledger.addTransactionBatch(&transactions);
```

## 💾 Persistence

### `saveToFile(filename: []const u8) !void`

Saves the entire ledger state to a file.

```zig
try ledger.saveToFile("ledger_backup.json");
```

### `loadFromFile(filename: []const u8) !void`

Loads ledger state from a file.

```zig
var ledger = zledger.Ledger.init(allocator);
try ledger.loadFromFile("ledger_backup.json");
```

## 🔐 Integration with Cryptographic Signing

### Signed Transaction Processing

```zig
const SignedTransaction = struct {
    transaction: zledger.Transaction,
    signature: zledger.Signature,
    signer_public_key: [32]u8,
};

pub fn processSignedTransaction(ledger: *zledger.Ledger, signed_tx: SignedTransaction) !void {
    // Serialize transaction for verification
    const tx_json = try std.json.stringifyAlloc(ledger.allocator, signed_tx.transaction, .{});
    defer ledger.allocator.free(tx_json);

    // Verify signature
    if (!zledger.verifySignature(tx_json, &signed_tx.signature.bytes, &signed_tx.signer_public_key)) {
        return error.InvalidSignature;
    }

    // Verify transaction business logic
    if (!try ledger.verifyTransaction(signed_tx.transaction)) {
        return error.InvalidTransaction;
    }

    // Add to ledger
    try ledger.addTransaction(signed_tx.transaction);

    std.debug.print("Signed transaction {} processed successfully\\n", .{signed_tx.transaction.id});
}
```

## ⚡ Performance Considerations

### Memory Management

```zig
// Use arena allocator for batch operations
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

var ledger = zledger.Ledger.init(arena.allocator());
// Ledger and all operations will be cleaned up automatically
```

### Large Ledger Handling

```zig
// For large ledgers, consider paginated operations
const BATCH_SIZE = 1000;
var offset: usize = 0;

while (true) {
    const transactions = try ledger.getTransactionPage(offset, BATCH_SIZE);
    if (transactions.len == 0) break;

    // Process batch
    for (transactions) |tx| {
        // Process transaction
    }

    offset += BATCH_SIZE;
}
```

## 🚨 Error Handling

### Common Errors

```zig
const LedgerError = error{
    AccountNotFound,
    InsufficientFunds,
    InvalidCurrency,
    DuplicateAccount,
    InvalidTransaction,
    AuditFailed,
};

// Error handling example
ledger.addTransaction(tx) catch |err| switch (err) {
    LedgerError.AccountNotFound => {
        std.debug.print("Account '{}' does not exist\\n", .{tx.from_account});
    },
    LedgerError.InsufficientFunds => {
        const balance = try ledger.getBalance(tx.from_account);
        std.debug.print("Insufficient funds. Available: ${d:.2}, Required: ${d:.2}\\n", .{
            balance.toFloat(),
            @as(f64, @floatFromInt(tx.amount)) / 100.0,
        });
    },
    LedgerError.InvalidCurrency => {
        std.debug.print("Currency '{}' is not registered\\n", .{tx.currency});
    },
    else => return err,
};
```

## 📊 Example: Complete Bookkeeping System

```zig
pub fn demonstrateBookkeeping(allocator: std.mem.Allocator) !void {
    var ledger = zledger.Ledger.init(allocator);
    defer ledger.deinit();

    // Set up chart of accounts
    try ledger.createAccount("cash", .asset, "USD");
    try ledger.createAccount("accounts_receivable", .asset, "USD");
    try ledger.createAccount("accounts_payable", .liability, "USD");
    try ledger.createAccount("owners_equity", .equity, "USD");
    try ledger.createAccount("sales_revenue", .revenue, "USD");
    try ledger.createAccount("office_expenses", .expense, "USD");

    // Initial capital investment
    try ledger.addTransaction(.{
        .id = "INIT-001",
        .amount = 1000000, // $10,000 initial investment
        .from_account = "owners_equity",
        .to_account = "cash",
        .currency = "USD",
        .timestamp = std.time.timestamp(),
        .memo = "Initial capital investment",
    });

    // Record a sale
    try ledger.addTransaction(.{
        .id = "SALE-001",
        .amount = 150000, // $1,500 sale
        .from_account = "accounts_receivable",
        .to_account = "sales_revenue",
        .currency = "USD",
        .timestamp = std.time.timestamp(),
        .memo = "Software consulting services",
    });

    // Customer payment received
    try ledger.addTransaction(.{
        .id = "PAY-001",
        .amount = 150000,
        .from_account = "cash",
        .to_account = "accounts_receivable",
        .currency = "USD",
        .timestamp = std.time.timestamp(),
        .memo = "Payment received for consulting",
    });

    // Office expenses
    try ledger.addTransaction(.{
        .id = "EXP-001",
        .amount = 50000, // $500 office rent
        .from_account = "office_expenses",
        .to_account = "cash",
        .currency = "USD",
        .timestamp = std.time.timestamp(),
        .memo = "Monthly office rent",
    });

    // Generate balance sheet
    const balance_sheet = try ledger.generateBalanceSheet();
    // Print balance sheet...

    // Run audit
    const audit = try ledger.runAudit();
    std.debug.print("Books balanced: {}\\n", .{audit.is_balanced});
}
```
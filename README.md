<div align="center">
  <img src="assets/icons/zledger.png" alt="Zledger Logo" width="200">
</div>

# Zledger: A Lightweight Ledger Engine in Zig

[![Zig v0.16.0-dev](https://img.shields.io/badge/zig-0.16.0--dev-f7a41d?logo=zig&logoColor=white)](https://ziglang.org/)
[![Pure Zig](https://img.shields.io/badge/pure-zig-success)](https://github.com/ziglang/zig)
[![Ledger Engine](https://img.shields.io/badge/type-ledger_engine-blue)](https://en.wikipedia.org/wiki/Ledger)
[![Double-Entry](https://img.shields.io/badge/accounting-double_entry-orange)](https://en.wikipedia.org/wiki/Double-entry_bookkeeping)
[![Ed25519 Signatures](https://img.shields.io/badge/crypto-Ed25519-red)](https://ed25519.cr.yp.to/)
[![Transaction Integrity](https://img.shields.io/badge/integrity-SHA256-purple)](https://en.wikipedia.org/wiki/SHA-2)
[![Financial Precision](https://img.shields.io/badge/precision-fixed_point-green)]()

## DISCLAIMER

⚠️ **EXPERIMENTAL LIBRARY - FOR LAB/PERSONAL USE** ⚠️

This is an experimental library under active development. It is intended for research, learning, and personal projects. The API is subject to change!

---

## 📌 Overview

**Zledger v0.5.0** is a lightweight, performant, and modular ledger engine built in Zig. It's designed for use in financial applications, cryptocurrency accounting, blockchain wallets, distributed systems, and local transactional systems where performance and precision matter.

Zledger provides foundational infrastructure for secure balance tracking, transaction journaling, double-entry accounting, audit-ready systems, smart contracts, and programmable transaction constraints—with flexible build options to include only what you need.

---

## 🎯 Goals

* ✅ **Modular architecture** — use only what you need via build flags
* ✅ **Minimal external dependencies** — uses modular zcrypto when crypto features enabled
* ✅ **Precision-first with no floating point leakage**
* ✅ **Supports both single and double-entry models**
* ✅ **Transaction chaining + integrity hashing with Merkle trees**
* ✅ **Built-in smart contracts and programmable constraints**
* ✅ **Cryptographic signing and verification (Zsig fully integrated)**
* ✅ **Identity-aware transactions for distributed systems**
* ✅ **Built for CLI, WASM, embedded, or distributed systems**

---

## 🧱 Core Modules

### 1. `zledger.tx`

Handles creation and serialization of transactions:

```zig
const Transaction = struct {
    id: []const u8,
    timestamp: i64,
    amount: i64,
    currency: []const u8,
    from_account: []const u8,
    to_account: []const u8,
    memo: ?[]const u8,
};
```

### 2. `zledger.account`

Manages accounts and balances. Supports double-entry verification and balance auditing.

### 3. `zledger.journal`

Flat append-only journal to store TX logs with optional integrity hash per transaction.

### 4. `zledger.audit`

Includes tools for integrity checks, balance diffs, and transaction history verification.

### 5. `zledger.rules`

Built-in support for attaching programmable constraints (formerly "covenants") to transactions or accounts:

* Custom transaction validation
* Spending limits (per account, asset, or time)
* Multi-signature/approval flows
* Allow/block lists and KYC enforcement
* Account- or transaction-level hooks for smart contract logic

#### Example: Custom Validation Rule

```zig
const AllowlistRule = struct {
    allowed: [][]const u8,
    pub fn validate(self: @This(), tx: Transaction) !void {
        if (!self.allowed.contains(tx.to_account)) return error.AccountNotAllowed;
    }
};

// Register a rule with the ledger
try zledger.rules.register(AllowlistRule{ .allowed = &[_][]const u8{"acct1", "acct2"} });
```

### 6. `zledger.cli`

A simple CLI interface to run operations:

```sh
zledger tx add --from user1 --to user2 --amount 1000 --memo "Refund"
zledger audit verify
zledger balance user2
```

### 7. `zledger.zsig` (Integrated Zsig)

Cryptographic signing and verification capabilities from the fully integrated Zsig library:

* Ed25519 transaction signing and verification
* Public/private keypair generation and management
* Secure transaction authentication and integrity
* Detached and inline signature support
* Deterministic signing for audit trails
* Challenge-response authentication
* Token and JWT signing capabilities

---

## 🔐 Security & Precision

* Fixed-point arithmetic using `i64` + `DECIMALS` (e.g. cents or micro-units)
* Optional SHA256 for integrity chaining of transactions
* Ed25519 cryptographic signing via integrated Zsig functionality
* No floats, no rounding errors, no surprises
* Programmable constraints prevent invalid or unauthorized transactions

---

## 🧠 Use Cases

* 💸 Embedded wallets (Zwallet)
* 📊 Local double-entry bookkeeping
* 🔐 Personal finance ledger in terminal
* 🌐 WASM-based transaction tracker for web apps
* 🧾 Audit trail system for smart contracts or DAOs
* ⚡ On-ledger programmable rules and constraints

---

## 🚀 What's New in v0.5.0

* **Modular Build System** - Choose which components to include:
  - `--ledger` - Core ledger functionality (default: true)
  - `--zsig` - Cryptographic signing (default: true)
  - `--contracts` - Smart contract execution (default: true)
  - `--crypto-storage` - Encrypted storage (default: true)
  - `--wallet` - Wallet integration (default: true)

* **Updated Modular Zcrypto** - Latest zcrypto library with feature flags
* **Smart Contracts** - Embedded contract execution with gas metering
* **Distributed System Support** - Identity-aware transactions and journal replay
* **Enhanced Documentation** - Comprehensive docs/ and examples/ directories
* **Keystone Integration** - Ready for integration with Keystone execution layer

## 📦 Installation & Build

### As a Zig Dependency

```bash
zig fetch --save https://github.com/ghostkellz/zledger/archive/refs/heads/main.tar.gz
```

Then in your `build.zig`:
```zig
const zledger = b.dependency("zledger", .{});
exe.root_module.addImport("zledger", zledger.module("zledger"));
```

### Build Configurations

```bash
# Full build with all features (default)
zig build

# Minimal ledger only
zig build -Dledger=true -Dzsig=false -Dcontracts=false -Dcrypto-storage=false -Dwallet=false

# Cryptographic features only
zig build -Dledger=false -Dzsig=true -Dcrypto-storage=true -Dwallet=false -Dcontracts=false

# Smart contracts with ledger
zig build -Dledger=true -Dcontracts=true -Dzsig=false -Dcrypto-storage=false -Dwallet=false
```

## 📚 Documentation

* [Quick Start Guide](docs/quick-start.md)
* [Build Configuration](docs/build-configuration.md)
* [Examples](examples/)
* [Keystone Integration](KEYSTONE.md)

## 🛠 Future Extensions

* Plugin hooks for syncing with Zwallet
* Zcash-style memo field support
* Export formats: CSV, JSON, and Merkle-tree snapshots
* Pluggable scripting/interpreter for advanced rule logic

---

## 🌍 License

MIT — Lightweight, auditable, and hacker-friendly.

---


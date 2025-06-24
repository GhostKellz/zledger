# Zledger: A Lightweight Ledger Engine in Zig

## 📌 Overview

**Zledger** is a lightweight, performant, and embeddable ledger engine built in Zig. It's designed for use in financial applications, cryptocurrency accounting, blockchain wallets, and local transactional systems where performance and precision matter.

Zledger aims to provide the foundational infrastructure for secure balance tracking, transaction journaling, double-entry accounting, and audit-ready systems.

---

## 🎯 Goals

* ✅ **Minimal yet powerful ledger engine**
* ✅ **No external dependencies** — just Zig and stdlib
* ✅ **Precision-first with no floating point leakage**
* ✅ **Supports both single and double-entry models**
* ✅ **Transaction chaining + integrity hashing**
* ✅ **Built for CLI, WASM, or embedded systems**

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

### 5. `zledger.cli`

A simple CLI interface to run operations:

```sh
zledger tx add --from user1 --to user2 --amount 1000 --memo "Refund"
zledger audit verify
zledger balance user2
```

---

## 🔐 Security & Precision

* Fixed-point arithmetic using `i64` + `DECIMALS` (e.g. cents or micro-units)
* Optional SHA256 for integrity chaining of transactions
* No floats, no rounding errors, no surprises

---

## 🧠 Use Cases

* 💸 Embedded wallets (Zwallet)
* 📊 Local double-entry bookkeeping
* 🔐 Personal finance ledger in terminal
* 🌐 WASM-based transaction tracker for web apps
* 🧾 Audit trail system for smart contracts or DAOs

---

## 🛠 Future Extensions

* Plugin hooks for syncing with Zwallet
* Zcash-style memo field support
* Zsig-compatible signing of transactions
* Export formats: CSV, JSON, and Merkle-tree snapshots

---

## 🌍 License

MIT — Lightweight, auditable, and hacker-friendly.

---

## 🤝 Related Projects

* [`zwallet`](./zwallet.md) — Local and hardware wallet integration
* [`zcrypto`](./zcrypto.md) — Zig cryptographic engine
* [`ghostforge`](https://github.com/ghostkellz/ghostforge) — Rust crates.io clone for self-hosted registries


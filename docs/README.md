# Zledger Documentation

Welcome to the Zledger documentation! Zledger is a lightweight, performant ledger engine built in Zig with integrated cryptographic signing capabilities.

## 📚 Documentation Structure

### [🔧 Integration Guide](integration/)
Learn how to integrate Zledger into your Zig projects using `zig fetch`.

### [📖 API Reference](api/)
Comprehensive API documentation for both ledger and cryptographic operations.

### [💡 Examples](examples/)
Practical examples and code samples for common use cases.

## 🚀 Quick Start

Add Zledger to your project:

```bash
zig fetch --save https://github.com/ghostkellz/zledger
```

Then in your `build.zig`:

```zig
const zledger = b.dependency("zledger", .{});
exe.root_module.addImport("zledger", zledger.module("zledger"));
```

## 📋 What's Included

- **Ledger Engine**: Double-entry accounting, transaction management, audit trails
- **Cryptographic Signing**: Ed25519 signatures via integrated Zsig library
- **CLI Tools**: Command-line interface for ledger and crypto operations
- **Precision Arithmetic**: Fixed-point math for financial calculations
- **Asset Management**: Multi-currency and asset support

## 🎯 Use Cases

- **Financial Applications**: Wallets, accounting systems, trading platforms
- **Blockchain Projects**: Transaction verification, audit trails
- **Embedded Systems**: Lightweight ledger for IoT and edge devices
- **Web Applications**: WASM-compatible transaction tracking

## 📄 License

MIT - Clean, modern, and embeddable.
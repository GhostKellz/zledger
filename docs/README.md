# Zledger Documentation

Zledger is a lightweight, modular ledger engine written in Zig, designed for cryptocurrency, financial applications, and smart contract systems.

## Table of Contents

- [Quick Start](quick-start.md)
- [Build Configuration](build-configuration.md)
- [Core Ledger API](core-ledger.md)
- [Cryptographic Signing (Zsig)](zsig-api.md)
- [Smart Contracts](smart-contracts.md)
- [Wallet Integration](wallet-integration.md)
- [Encrypted Storage](encrypted-storage.md)
- [Examples](../examples/)

## Features

Zledger provides a modular architecture with the following components:

### Core Ledger (--ledger=true)
- **Accounts**: Multi-type account management (Assets, Liabilities, Equity, Revenue, Expenses)
- **Transactions**: Double-entry bookkeeping with validation
- **Journal**: Transaction recording and auditing
- **Audit**: Built-in audit trail and compliance checking
- **Fixed Point Math**: Precise financial calculations
- **Assets**: Multi-asset support with metadata
- **Merkle Trees**: Data integrity verification

### Cryptographic Signing (--zsig=true)
- **Ed25519 Signatures**: Fast and secure digital signatures
- **Key Generation**: Cryptographically secure keypair generation
- **Message Authentication**: Sign and verify arbitrary data
- **Token Support**: JWT-like token creation and validation

### Smart Contracts (--contracts=true)
- **Embedded VM**: Lightweight contract execution environment
- **Gas Metering**: Resource usage tracking
- **State Management**: Persistent contract state
- **Inter-contract Communication**: Contract-to-contract calls

### Encrypted Storage (--crypto-storage=true)
- **File Encryption**: Secure file storage with AES-256
- **Key Management**: Secure key derivation and storage
- **Data Integrity**: HMAC-based authentication

### Wallet Integration (--wallet=true)
- **HD Wallets**: Hierarchical Deterministic wallet support
- **Multiple Algorithms**: Support for various signature schemes
- **Transaction Signing**: Secure transaction authorization

## Build Configurations

Zledger supports flexible build configurations to include only the components you need:

```bash
# Full build (default)
zig build

# Core ledger only
zig build -Dledger=true -Dzsig=false -Dcontracts=false -Dcrypto-storage=false -Dwallet=false

# Zsig signing only
zig build -Dledger=false -Dzsig=true -Dcontracts=false -Dcrypto-storage=false -Dwallet=false

# Smart contracts with core ledger
zig build -Dledger=true -Dcontracts=true -Dzsig=false -Dcrypto-storage=false -Dwallet=false
```

## Getting Started

See [Quick Start Guide](quick-start.md) for installation and basic usage.

## Version

Current version: **0.5.0** (Release Candidate)

## License

This project is open source. See LICENSE file for details.
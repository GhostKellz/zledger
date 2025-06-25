# Changelog

All notable changes to zledger will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-06-25

### 🚀 **MAJOR RELEASE: Cryptographic Integrity & Security Overhaul**

This is a major security-focused release that transforms zledger from a basic ledger engine into a cryptographically secure, enterprise-grade financial system with comprehensive integrity verification, encrypted storage, and multi-algorithm transaction signing.

### Added

#### 🔐 **Cryptographic Transaction Integrity**
- **Digital Signatures**: Ed25519 and secp256k1 transaction signing support
- **HMAC Authentication**: SHA-256 HMAC for transaction integrity verification
- **Cryptographic Nonces**: 12-byte random nonces for transaction uniqueness
- **Signature Verification**: Constant-time signature validation
- **Multi-Algorithm Support**: Ed25519 (fast) and secp256k1 (Bitcoin-compatible)

#### 🛡️ **HMAC-Based Audit Trails**
- **Audit Trail HMAC**: Cryptographic integrity for entire audit trails
- **Individual Transaction HMAC**: Per-transaction integrity verification
- **Audit Key Management**: Secure audit key generation and storage
- **Tamper Detection**: Constant-time HMAC verification prevents timing attacks
- **Chain Integrity**: Cryptographic verification of journal entry chains

#### 🔒 **Secure Data Storage (AES-GCM)**
- **EncryptedStorage**: AES-256-GCM encryption for sensitive data
- **SecureFile**: Password-based encrypted file operations
- **Argon2id Key Derivation**: Modern password-based key stretching
- **Encrypted Journal Persistence**: Save/load journal data with encryption
- **Secure Memory Handling**: Automatic zeroing of sensitive data

#### 💳 **zwallet Integration**
- **WalletKeypair**: Multi-algorithm keypair generation and management
- **TransactionSigner**: Secure transaction signing with HMAC
- **HD Wallet Support**: Hierarchical deterministic wallet derivation
- **Address Generation**: Algorithm-specific address formats
- **Wallet Info**: Public key and address management utilities

#### ⚡ **Constant-Time Security Operations**
- **Timing Attack Prevention**: All cryptographic comparisons use constant-time operations
- **Hash Comparison**: Secure hash verification in journal and audit systems
- **HMAC Verification**: Constant-time HMAC validation
- **Signature Verification**: Timing-safe signature checking

#### 🧪 **Comprehensive Cryptographic Test Suite**
- **End-to-End Workflow Tests**: Complete cryptographic transaction lifecycle
- **Security Validation**: Multi-layer security verification testing
- **Audit Trail Testing**: HMAC integrity and tamper detection tests
- **Encrypted Storage Tests**: AES-GCM encryption/decryption validation
- **Multi-Algorithm Tests**: Ed25519 and secp256k1 compatibility testing
- **Constant-Time Operation Tests**: Timing attack prevention validation

### Enhanced

#### 🔧 **Core Transaction System**
- **Enhanced Transaction Structure**: Added `signature`, `integrity_hmac`, and `nonce` fields
- **Cryptographic Transaction ID**: Secure hash-based transaction identification
- **JSON Serialization**: Extended to include all cryptographic fields
- **Data Integrity**: Deterministic transaction data for signing

#### 📊 **Audit System Improvements**
- **Extended AuditReport**: Added `hmac_valid` field and audit trail HMAC
- **Enhanced Verification**: Multi-layer integrity checking
- **Cryptographic Auditor**: Secure audit key management
- **Comprehensive Validation**: HMAC, signature, and chain integrity verification

#### 📁 **Journal System Security**
- **Encrypted Persistence**: Save/load journals with password protection
- **Chain Verification**: Constant-time hash comparison for integrity
- **Secure File Operations**: Encrypted journal backup and restore
- **Cryptographic Entry Hashing**: Enhanced security for journal entries

#### 🏗️ **Build System & Dependencies**
- **zcrypto Integration**: Full integration with zcrypto v0.2.0
- **Enhanced build.zig**: Proper dependency management and module imports
- **Cross-Platform Support**: Maintained compatibility across platforms

### Technical Details

#### 🔧 **New Modules**
- `src/crypto_storage.zig` - AES-GCM encrypted storage system
- `src/zwallet_integration.zig` - Wallet and transaction signing integration
- `src/crypto_tests.zig` - Comprehensive cryptographic test suite

#### 🏗️ **Architecture Enhancements**
- **Modular Cryptography**: Pluggable cryptographic backends
- **Secure Defaults**: All new features use secure-by-default configurations
- **Memory Safety**: Automatic sensitive data zeroing throughout system
- **Error Handling**: Comprehensive error handling for all cryptographic operations

#### 🎯 **Security Features**
```zig
// Transaction with full cryptographic integrity
pub const Transaction = struct {
    // ... existing fields ...
    signature: ?[64]u8,        // Ed25519/secp256k1 signature
    integrity_hmac: ?[32]u8,   // SHA-256 HMAC
    nonce: [12]u8,             // Cryptographic nonce
};

// HMAC-secured audit reports
pub const AuditReport = struct {
    // ... existing fields ...
    hmac_valid: bool,          // HMAC verification status
    audit_trail_hmac: [32]u8,  // Audit trail integrity HMAC
};
```

#### 📦 **Dependencies**
- **Added**: `zcrypto` v0.2.0 - Comprehensive cryptographic library
- **Enhanced**: Build system integration for cryptographic modules
- **Maintained**: Zero external C dependencies
- **Compatible**: Zig 0.15.0-dev.822+

### Migration Guide

#### From v0.1.x to v0.2.0

**For Existing Ledger Users:**
```zig
// Old (still works)
var transaction = try Transaction.init(allocator, amount, currency, from, to, memo);

// New (with cryptographic integrity)
var transaction = try Transaction.init(allocator, amount, currency, from, to, memo);
var signer = TransactionSigner.init(wallet_keypair);
try signer.signTransaction(allocator, &transaction);
```

**For Audit Trail Users:**
```zig
// Old
var auditor = Auditor.init(allocator);
var report = try auditor.auditLedger(&ledger, &journal);

// New (with HMAC verification)
var auditor = Auditor.initWithKey(allocator, audit_key);
var report = try auditor.auditLedger(&ledger, &journal);
// report.hmac_valid now indicates cryptographic integrity
```

**For Journal Persistence:**
```zig
// Old (plaintext)
try journal.saveToFile("ledger.log");

// New (encrypted)
try journal.saveToEncryptedFile("ledger.enc", password);
```

### Breaking Changes

1. **Transaction Structure**: Added cryptographic fields (`signature`, `integrity_hmac`, `nonce`)
2. **AuditReport Structure**: Added HMAC validation fields
3. **Build Dependencies**: Now requires `zcrypto` for full functionality
4. **API Extensions**: New cryptographic methods alongside existing APIs

### Compatibility

- ✅ **Backward Compatible**: Existing transaction creation APIs unchanged
- ✅ **Optional Crypto**: Cryptographic features are opt-in enhancements
- ✅ **WASM Ready**: All cryptographic operations support WASM compilation
- ✅ **Embedded Friendly**: Maintained low memory footprint
- ✅ **zwallet Ready**: Full integration with zwallet ecosystem

### Security Improvements

- **Timing Attack Prevention**: All cryptographic comparisons use constant-time operations
- **Memory Safety**: Automatic sensitive data clearing with `zcrypto.util.secureZero`
- **Cryptographic Randomness**: Secure random generation for nonces and keys
- **Modern Algorithms**: Ed25519 and secp256k1 with latest security practices
- **Authenticated Encryption**: AES-GCM for confidentiality and integrity
- **Key Derivation**: Argon2id for password-based key derivation

### Performance

- **Optimized Crypto**: Hardware-accelerated operations via zcrypto
- **Efficient Storage**: Compact encrypted data formats
- **Fast Verification**: Optimized signature and HMAC verification
- **Memory Efficient**: Stack-allocated cryptographic structures
- **Parallel Operations**: Support for concurrent cryptographic operations

---

## [0.1.0] - 2024-XX-XX

### Added
- Initial ledger engine implementation
- Basic transaction support with double-entry bookkeeping
- Account management (asset, liability, equity, revenue, expense)
- Journal entry system with chain integrity
- Audit functionality with balance verification
- CLI interface for ledger operations
- File-based persistence (plaintext)
- Fixed-point arithmetic for precise calculations

### Features
- Transaction creation and validation
- Account balance tracking
- Journal chain verification
- Basic audit reports
- Command-line interface
- File import/export

---

## Future Roadmap

### Planned for v0.3.0
- Hardware Security Module (HSM) integration
- Multi-signature transaction support
- Advanced key management (hardware wallets)
- Performance optimizations for large datasets
- Additional cryptographic algorithms

### Long-term Goals
- Quantum-resistant cryptography preparation
- Zero-knowledge proof integration
- Advanced privacy features
- Enterprise compliance features (SOX, PCI-DSS)
- Distributed ledger capabilities

---

**Full Changelog**: https://github.com/ghostkellz/zledger/compare/v0.1.0...v0.2.0

## Security Notice

This release introduces significant cryptographic enhancements. All users are encouraged to:

1. **Update Dependencies**: Ensure `zcrypto` v0.2.0 is properly installed
2. **Review Security**: Understand new cryptographic features before production use
3. **Test Thoroughly**: Run comprehensive test suite to validate integration
4. **Backup Safely**: Use encrypted persistence for sensitive ledger data
5. **Key Management**: Implement proper key storage and rotation procedures

For security-related questions or concerns, please review our security documentation or contact the maintainers.
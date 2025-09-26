//! Zledger - A Lightweight Ledger Engine in Zig
const std = @import("std");
const build_options = @import("build_options");

// Core ledger functionality
pub const tx = if (build_options.enable_ledger) @import("tx.zig") else void;
pub const account = if (build_options.enable_ledger) @import("account.zig") else void;
pub const journal = if (build_options.enable_ledger) @import("journal.zig") else void;
pub const audit = if (build_options.enable_ledger) @import("audit.zig") else void;
pub const cli = @import("cli.zig");
pub const fixed_point = if (build_options.enable_ledger) @import("fixed_point.zig") else void;
pub const asset = if (build_options.enable_ledger) @import("asset.zig") else void;
pub const merkle = if (build_options.enable_ledger) @import("merkle.zig") else void;

// Cryptographic functionality
pub const crypto_storage = if (build_options.enable_crypto_storage) @import("crypto_storage.zig") else void;
pub const zsig = if (build_options.enable_zsig) @import("zsig.zig") else void;

// Wallet integration
pub const zwallet_integration = if (build_options.enable_wallet_integration) @import("zwallet_integration.zig") else void;

// Smart contracts
pub const contract = if (build_options.enable_contracts) @import("contract.zig") else void;

// Comprehensive tests - only test what's enabled
test {
    if (build_options.enable_crypto_storage) _ = @import("crypto_tests.zig");
    if (build_options.enable_contracts) _ = @import("contract.zig");
    if (build_options.enable_ledger) _ = @import("merkle.zig");
    if (build_options.enable_ledger) _ = @import("asset.zig");
    if (build_options.enable_zsig) _ = @import("zsig.zig");
    if (build_options.enable_zsig) _ = @import("zsig_integration_test.zig");
}

// Core ledger exports (conditional)
pub const Transaction = if (build_options.enable_ledger) tx.Transaction else void;
pub const Account = if (build_options.enable_ledger) account.Account else void;
pub const AccountType = if (build_options.enable_ledger) account.AccountType else void;
pub const Ledger = if (build_options.enable_ledger) account.Ledger else void;
pub const Journal = if (build_options.enable_ledger) journal.Journal else void;
pub const JournalEntry = if (build_options.enable_ledger) journal.JournalEntry else void;
pub const Auditor = if (build_options.enable_ledger) audit.Auditor else void;
pub const AuditReport = if (build_options.enable_ledger) audit.AuditReport else void;
pub const FixedPoint = if (build_options.enable_ledger) fixed_point.FixedPoint else void;
pub const Asset = if (build_options.enable_ledger) asset.Asset else void;
pub const AssetRegistry = if (build_options.enable_ledger) asset.AssetRegistry else void;

// CLI is always available
pub const Cli = cli.Cli;

// Crypto storage exports (conditional)
pub const EncryptedStorage = if (build_options.enable_crypto_storage) crypto_storage.EncryptedStorage else void;
pub const EncryptedData = if (build_options.enable_crypto_storage) crypto_storage.EncryptedData else void;
pub const SecureFile = if (build_options.enable_crypto_storage) crypto_storage.SecureFile else void;

// Wallet integration exports (conditional)
pub const WalletKeypair = if (build_options.enable_wallet_integration) zwallet_integration.WalletKeypair else void;
pub const TransactionSigner = if (build_options.enable_wallet_integration) zwallet_integration.TransactionSigner else void;
pub const WalletInfo = if (build_options.enable_wallet_integration) zwallet_integration.WalletInfo else void;
pub const HDWallet = if (build_options.enable_wallet_integration) zwallet_integration.HDWallet else void;
pub const SignatureAlgorithm = if (build_options.enable_wallet_integration) zwallet_integration.SignatureAlgorithm else void;

// Integrated Zsig Cryptographic Signing (conditional)
pub const Keypair = if (build_options.enable_zsig) zsig.Keypair else void;
pub const Signature = if (build_options.enable_zsig) zsig.Signature else void;
pub const VerificationResult = if (build_options.enable_zsig) zsig.VerificationResult else void;
pub const generateKeypair = if (build_options.enable_zsig) zsig.generateKeypair else void;
pub const signMessage = if (build_options.enable_zsig) zsig.signMessage else void;
pub const verifySignature = if (build_options.enable_zsig) zsig.verifySignature else void;

// Embedded Smart Contract System (conditional)
pub const ContractError = if (build_options.enable_contracts) contract.ContractError else void;
pub const GasLimit = if (build_options.enable_contracts) contract.GasLimit else void;
pub const ContractAddress = if (build_options.enable_contracts) contract.ContractAddress else void;
pub const StateHash = if (build_options.enable_contracts) contract.StateHash else void;
pub const ContractState = if (build_options.enable_contracts) contract.ContractState else void;
pub const ExecutionContext = if (build_options.enable_contracts) contract.ExecutionContext else void;
pub const Contract = if (build_options.enable_contracts) contract.Contract else void;

pub fn advancedPrint() !void {
    std.debug.print("Zledger - Lightweight Ledger Engine\n", .{});
    std.debug.print("Run `zig build test` to run the tests.\n", .{});
    std.debug.print("Use `zledger --help` for CLI usage.\n", .{});
}

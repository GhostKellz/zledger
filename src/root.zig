//! Zledger - A Lightweight Ledger Engine in Zig
const std = @import("std");

pub const tx = @import("tx.zig");
pub const account = @import("account.zig");
pub const journal = @import("journal.zig");
pub const audit = @import("audit.zig");
pub const cli = @import("cli.zig");
pub const fixed_point = @import("fixed_point.zig");
pub const crypto_storage = @import("crypto_storage.zig");
pub const zwallet_integration = @import("zwallet_integration.zig");
pub const contract = @import("contract.zig");
pub const merkle = @import("merkle.zig");
pub const asset = @import("asset.zig");

// Comprehensive tests
test {
    _ = @import("crypto_tests.zig");
    _ = @import("contract.zig");
    _ = @import("merkle.zig");
    _ = @import("asset.zig");
}

pub const Transaction = tx.Transaction;
pub const Account = account.Account;
pub const AccountType = account.AccountType;
pub const Ledger = account.Ledger;
pub const Journal = journal.Journal;
pub const JournalEntry = journal.JournalEntry;
pub const Auditor = audit.Auditor;
pub const AuditReport = audit.AuditReport;
pub const Cli = cli.Cli;
pub const FixedPoint = fixed_point.FixedPoint;
pub const EncryptedStorage = crypto_storage.EncryptedStorage;
pub const EncryptedData = crypto_storage.EncryptedData;
pub const SecureFile = crypto_storage.SecureFile;
pub const WalletKeypair = zwallet_integration.WalletKeypair;
pub const TransactionSigner = zwallet_integration.TransactionSigner;
pub const WalletInfo = zwallet_integration.WalletInfo;
pub const HDWallet = zwallet_integration.HDWallet;
pub const SignatureAlgorithm = zwallet_integration.SignatureAlgorithm;
pub const Asset = asset.Asset;
pub const AssetRegistry = asset.AssetRegistry;

// Embedded Smart Contract System
pub const ContractError = contract.ContractError;
pub const GasLimit = contract.GasLimit;
pub const ContractAddress = contract.ContractAddress;
pub const StateHash = contract.StateHash;
pub const ContractState = contract.ContractState;
pub const ExecutionContext = contract.ExecutionContext;
pub const Contract = contract.Contract;

pub fn advancedPrint() !void {
    std.debug.print("Zledger - Lightweight Ledger Engine\n", .{});
    std.debug.print("Run `zig build test` to run the tests.\n", .{});
    std.debug.print("Use `zledger --help` for CLI usage.\n", .{});
}

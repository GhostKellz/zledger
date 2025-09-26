//! Cryptographic Signing Example
//! This example demonstrates Zsig cryptographic functionality including:
//! - Key generation
//! - Message signing
//! - Signature verification
//! - Token creation and validation

const std = @import("std");
const zledger = @import("zledger");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Zledger Cryptographic Signing Example ===\n\n");

    // Generate a keypair
    std.debug.print("Generating Ed25519 keypair...\n");
    const keypair = try zledger.generateKeypair();

    // Display public key (hex encoded)
    var pubkey_hex: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&pubkey_hex, "{}", .{std.fmt.fmtSliceHexUpper(&keypair.public_key)}) catch unreachable;
    std.debug.print("Public Key: {s}\n", .{pubkey_hex});

    // Sign various types of messages
    const messages = [_][]const u8{
        "Hello, Zledger!",
        "This is a financial transaction",
        "Smart contract execution data",
        "Blockchain block data",
    };

    std.debug.print("\n=== Message Signing ===\n");
    for (messages, 0..) |message, i| {
        std.debug.print("{}. Message: \"{s}\"\n", .{ i + 1, message });

        // Sign the message
        const signature = try zledger.signMessage(keypair, message);

        // Verify the signature
        const verification_result = try zledger.verifySignature(
            keypair.public_key,
            message,
            signature
        );

        std.debug.print("   Signature: {}...{}\n", .{
            std.fmt.fmtSliceHexUpper(signature.data[0..8]),
            std.fmt.fmtSliceHexUpper(signature.data[56..64]),
        });
        std.debug.print("   Valid: {}\n", .{verification_result == .Valid});

        // Test with wrong message (should fail)
        const wrong_message = "Wrong message";
        const wrong_verification = try zledger.verifySignature(
            keypair.public_key,
            wrong_message,
            signature
        );
        std.debug.print("   Wrong message verification: {}\n\n", .{wrong_verification == .Valid});
    }

    // Demonstrate token creation and validation
    std.debug.print("=== Token Creation ===\n");

    // Create a token with claims
    const token_data = TokenClaims{
        .user_id = "alice",
        .permissions = &[_][]const u8{ "read", "write", "admin" },
        .expiry = std.time.timestamp() + 3600, // 1 hour from now
        .issuer = "zledger-example",
    };

    // Serialize token data
    var token_buffer: [512]u8 = undefined;
    const token_json = try std.json.stringifyAlloc(allocator, token_data, .{});
    defer allocator.free(token_json);

    std.debug.print("Token Claims: {s}\n", .{token_json});

    // Sign the token
    const token_signature = try zledger.signMessage(keypair, token_json);

    // Create a complete signed token
    const signed_token = SignedToken{
        .claims = token_data,
        .signature = token_signature,
        .public_key = keypair.public_key,
    };

    std.debug.print("Token created and signed successfully\n");

    // Verify the token
    const token_verification = try zledger.verifySignature(
        signed_token.public_key,
        token_json,
        signed_token.signature
    );

    std.debug.print("Token signature valid: {}\n", .{token_verification == .Valid});

    // Demonstrate multi-signature scenario
    std.debug.print("\n=== Multi-Signature Example ===\n");

    // Generate additional keypairs for multi-sig
    const keypair2 = try zledger.generateKeypair();
    const keypair3 = try zledger.generateKeypair();

    const multisig_message = "Multi-signature transaction: Transfer $1000 from Alice to Bob";
    std.debug.print("Message: \"{s}\"\n", .{multisig_message});

    // Each party signs the message
    const sig1 = try zledger.signMessage(keypair, multisig_message);
    const sig2 = try zledger.signMessage(keypair2, multisig_message);
    const sig3 = try zledger.signMessage(keypair3, multisig_message);

    std.debug.print("Signature 1 valid: {}\n", .{
        try zledger.verifySignature(keypair.public_key, multisig_message, sig1) == .Valid
    });
    std.debug.print("Signature 2 valid: {}\n", .{
        try zledger.verifySignature(keypair2.public_key, multisig_message, sig2) == .Valid
    });
    std.debug.print("Signature 3 valid: {}\n", .{
        try zledger.verifySignature(keypair3.public_key, multisig_message, sig3) == .Valid
    });

    // Demonstrate signature with different data types
    std.debug.print("\n=== Binary Data Signing ===\n");

    // Create some binary data (simulating transaction data)
    const transaction_data = TransactionData{
        .from = "alice_wallet",
        .to = "bob_wallet",
        .amount = 50000, // in smallest currency unit
        .nonce = 12345,
        .timestamp = std.time.timestamp(),
    };

    // Serialize as binary
    var tx_buffer: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&tx_buffer);
    try std.json.stringify(transaction_data, .{}, stream.writer());
    const tx_bytes = stream.getWritten();

    std.debug.print("Transaction data: {s}\n", .{tx_bytes});

    // Sign the binary data
    const tx_signature = try zledger.signMessage(keypair, tx_bytes);

    // Verify
    const tx_verification = try zledger.verifySignature(
        keypair.public_key,
        tx_bytes,
        tx_signature
    );

    std.debug.print("Transaction signature valid: {}\n", .{tx_verification == .Valid});

    std.debug.print("\n=== Example Complete ===\n");
}

// Example data structures for tokens
const TokenClaims = struct {
    user_id: []const u8,
    permissions: []const []const u8,
    expiry: i64,
    issuer: []const u8,
};

const SignedToken = struct {
    claims: TokenClaims,
    signature: zledger.Signature,
    public_key: [32]u8,
};

// Example transaction data structure
const TransactionData = struct {
    from: []const u8,
    to: []const u8,
    amount: u64,
    nonce: u64,
    timestamp: i64,
};
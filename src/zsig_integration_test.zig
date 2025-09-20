//! Integration test for zsig functionality in zledger
const std = @import("std");
const zledger = @import("root.zig");

test "zsig integration with zledger transactions" {
    const allocator = std.testing.allocator;

    // Test zsig keypair generation
    const keypair = try zledger.generateKeypair(allocator);

    // Test signing a simple message
    const message = "zledger transaction: alice -> bob, 1000 USD";
    const signature = try zledger.signMessage(message, keypair);

    // Test signature verification
    const is_valid = zledger.verifySignature(message, &signature.bytes, &keypair.publicKey());
    try std.testing.expect(is_valid);

    // Test that invalid signature fails
    const invalid_signature = try zledger.signMessage("different message", keypair);
    const is_invalid = zledger.verifySignature(message, &invalid_signature.bytes, &keypair.publicKey());
    try std.testing.expect(!is_invalid);
}

test "zsig key formats and serialization" {
    const allocator = std.testing.allocator;

    // Test keypair generation and format conversion
    const keypair = try zledger.generateKeypair(allocator);

    // Test hex conversion
    const pub_hex = try keypair.publicKeyHex(allocator);
    defer allocator.free(pub_hex);

    try std.testing.expect(pub_hex.len == 64); // 32 bytes * 2 hex chars

    // Test private key base64 conversion
    const priv_b64 = try keypair.privateKeyBase64(allocator);
    defer allocator.free(priv_b64);

    try std.testing.expect(priv_b64.len > 0);

    // Test keypair bundle export
    const bundle = try keypair.exportBundle(allocator);
    defer allocator.free(bundle);

    try std.testing.expect(std.mem.indexOf(u8, bundle, "-----BEGIN ZSIG KEYPAIR-----") != null);
    try std.testing.expect(std.mem.indexOf(u8, bundle, "-----END ZSIG KEYPAIR-----") != null);
}

test "zsig deterministic operations for audit trails" {

    // Test deterministic keypair generation from seed
    const seed = [_]u8{42} ** 32; // Fixed seed for deterministic test
    const kp1 = zledger.zsig.keypairFromSeed(seed);
    const kp2 = zledger.zsig.keypairFromSeed(seed);

    // Verify they produce identical keys
    try std.testing.expectEqualSlices(u8, &kp1.publicKey(), &kp2.publicKey());
    try std.testing.expectEqualSlices(u8, &kp1.secretKey(), &kp2.secretKey());

    // Test deterministic signing
    const message = "deterministic ledger transaction";
    const sig1 = try zledger.signMessage(message, kp1);
    const sig2 = try zledger.signMessage(message, kp2);

    // Verify signatures are identical
    try std.testing.expectEqualSlices(u8, &sig1.bytes, &sig2.bytes);
}
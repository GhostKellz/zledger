# Zsig API Reference

The Zsig module provides cryptographic signing and verification using Ed25519 signatures. This is the integrated version of the standalone Zsig library.

## 🔧 Core Functions

### Key Generation

#### `generateKeypair(allocator: std.mem.Allocator) !Keypair`

Generates a new Ed25519 keypair using cryptographically secure randomness.

```zig
const keypair = try zledger.generateKeypair(allocator);
const public_key = keypair.publicKey();
const secret_key = keypair.secretKey();
```

#### `keypairFromSeed(seed: [32]u8) Keypair`

Generates a deterministic keypair from a 32-byte seed. Useful for reproducible key generation.

```zig
const seed = [_]u8{42} ** 32; // Use secure source
const keypair = zledger.zsig.keypairFromSeed(seed);
```

#### `keypairFromPassphrase(allocator: std.mem.Allocator, passphrase: []const u8, salt: ?[]const u8) !Keypair`

Generates a keypair from a passphrase using PBKDF2 key derivation.

```zig
const keypair = try zledger.zsig.keypairFromPassphrase(
    allocator,
    "my secure passphrase",
    "optional-salt"
);
```

### Signing Operations

#### `signMessage(message: []const u8, keypair: Keypair) !Signature`

Signs a message using Ed25519 algorithm.

```zig
const message = "Hello, World!";
const signature = try zledger.signMessage(message, keypair);
```

#### `signBytes(data: []const u8, keypair: Keypair) !Signature`

Signs arbitrary byte data.

```zig
const data = [_]u8{0x01, 0x02, 0x03, 0x04};
const signature = try zledger.zsig.signBytes(&data, keypair);
```

#### `signInline(allocator: std.mem.Allocator, message: []const u8, keypair: Keypair) ![]u8`

Creates an inline signature (message + signature combined).

```zig
const signed_message = try zledger.zsig.signInline(allocator, "Hello", keypair);
defer allocator.free(signed_message);
// signed_message contains: message || signature
```

#### `signWithContext(message: []const u8, context: []const u8, keypair: Keypair) !Signature`

Signs a message with additional context for domain separation.

```zig
const signature = try zledger.zsig.signWithContext(
    "transaction data",
    "zledger-v1",
    keypair
);
```

#### `signBatch(allocator: std.mem.Allocator, messages: []const []const u8, keypair: Keypair) ![]Signature`

Signs multiple messages efficiently.

```zig
const messages = [_][]const u8{ "msg1", "msg2", "msg3" };
const signatures = try zledger.zsig.signBatch(allocator, &messages, keypair);
defer allocator.free(signatures);
```

### Verification Operations

#### `verifySignature(message: []const u8, signature: []const u8, public_key: []const u8) bool`

Verifies a signature against a message and public key.

```zig
const is_valid = zledger.verifySignature(
    message,
    &signature.bytes,
    &keypair.publicKey()
);

if (is_valid) {
    std.debug.print("Signature is valid!\\n", .{});
}
```

#### `verifyInline(signed_message: []const u8, public_key: []const u8) bool`

Verifies an inline signature.

```zig
const is_valid = zledger.zsig.verifyInline(signed_message, &keypair.publicKey());
```

#### `verifyWithContext(message: []const u8, context: []const u8, signature: []const u8, public_key: []const u8) bool`

Verifies a signature created with context.

```zig
const is_valid = zledger.zsig.verifyWithContext(
    "transaction data",
    "zledger-v1",
    &signature.bytes,
    &public_key
);
```

#### `verifyBatch(messages: []const []const u8, signatures: []const Signature, public_keys: []const [32]u8) bool`

Verifies multiple signatures efficiently.

```zig
const all_valid = zledger.zsig.verify.verifyBatch(
    &messages,
    signatures,
    &public_keys
);
```

#### `verifyBatchSameKey(messages: []const []const u8, signatures: []const Signature, public_key: [32]u8) bool`

Verifies multiple signatures with the same public key.

```zig
const all_valid = zledger.zsig.verify.verifyBatchSameKey(
    &messages,
    signatures,
    keypair.publicKey()
);
```

## 📊 Data Structures

### Keypair

```zig
pub const Keypair = struct {
    inner: backend.Keypair,

    // Key access
    pub fn publicKey(self: *const Self) [32]u8;
    pub fn secretKey(self: *const Self) [32]u8;

    // Export formats
    pub fn publicKeyHex(self: *const Self, allocator: std.mem.Allocator) ![]u8;
    pub fn privateKeyBase64(self: *const Self, allocator: std.mem.Allocator) ![]u8;
    pub fn exportBundle(self: *const Self, allocator: std.mem.Allocator) ![]u8;

    // Import
    pub fn fromPrivateKeyBase64(private_key_b64: []const u8) !Self;
};
```

### Signature

```zig
pub const Signature = struct {
    bytes: [64]u8,

    pub fn toHex(self: Signature, allocator: std.mem.Allocator) ![]u8;
    pub fn fromHex(hex: []const u8) !Signature;
    pub fn toBase64(self: Signature, allocator: std.mem.Allocator) ![]u8;
    pub fn fromBase64(b64: []const u8) !Signature;
};
```

### Constants

```zig
pub const PUBLIC_KEY_SIZE = 32;
pub const PRIVATE_KEY_SIZE = 32;
pub const SIGNATURE_SIZE = 64;
pub const SEED_SIZE = 32;
```

## 🔐 Security Features

### Deterministic Signing

Ed25519 signatures are deterministic by design - the same message and private key will always produce the same signature.

```zig
const message = "test message";
const sig1 = try zledger.signMessage(message, keypair);
const sig2 = try zledger.signMessage(message, keypair);
// sig1.bytes equals sig2.bytes
```

### Context Separation

Use context signing to prevent signature reuse across different domains:

```zig
// Different contexts produce different signatures
const sig_tx = try zledger.zsig.signWithContext(data, "transaction", keypair);
const sig_auth = try zledger.zsig.signWithContext(data, "authentication", keypair);
// sig_tx != sig_auth
```

### Challenge-Response

For authentication protocols:

```zig
// Server sends challenge
const challenge = "random-challenge-12345";

// Client signs challenge
const response = try zledger.zsig.signWithContext(
    challenge,
    "auth-challenge",
    client_keypair
);

// Server verifies
const is_authenticated = zledger.zsig.verifyWithContext(
    challenge,
    "auth-challenge",
    &response.bytes,
    &client_public_key
);
```

## 🚀 Performance Tips

### Batch Operations

When signing/verifying multiple items:

```zig
// Instead of individual operations:
for (messages) |msg| {
    const sig = try zledger.signMessage(msg, keypair);
    // Process signature
}

// Use batch operations:
const signatures = try zledger.zsig.signBatch(allocator, &messages, keypair);
defer allocator.free(signatures);
```

### Keypair Reuse

Generate keypairs once and reuse them:

```zig
// Generate once
const signing_keypair = try zledger.generateKeypair(allocator);

// Reuse for multiple signatures
const sig1 = try zledger.signMessage("msg1", signing_keypair);
const sig2 = try zledger.signMessage("msg2", signing_keypair);
```

### Memory Management

Use arena allocators for temporary operations:

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
const arena_alloc = arena.allocator();

// All allocations cleaned up automatically
const signatures = try zledger.zsig.signBatch(arena_alloc, &messages, keypair);
```

## 🔗 Integration Examples

### Transaction Signing

```zig
fn signTransaction(tx: zledger.Transaction, signer: zledger.Keypair, allocator: std.mem.Allocator) !zledger.Signature {
    // Serialize transaction to canonical format
    const tx_json = try std.json.stringifyAlloc(allocator, tx, .{});
    defer allocator.free(tx_json);

    // Sign the serialized data
    return try zledger.signMessage(tx_json, signer);
}

fn verifyTransaction(tx: zledger.Transaction, signature: zledger.Signature, public_key: [32]u8, allocator: std.mem.Allocator) !bool {
    const tx_json = try std.json.stringifyAlloc(allocator, tx, .{});
    defer allocator.free(tx_json);

    return zledger.verifySignature(tx_json, &signature.bytes, &public_key);
}
```

### Key Storage

```zig
fn saveKeypair(keypair: zledger.Keypair, filename: []const u8, allocator: std.mem.Allocator) !void {
    const bundle = try keypair.exportBundle(allocator);
    defer allocator.free(bundle);

    try std.fs.cwd().writeFile(.{ .sub_path = filename, .data = bundle });
}

fn loadKeypair(filename: []const u8, allocator: std.mem.Allocator) !zledger.Keypair {
    const content = try std.fs.cwd().readFileAlloc(allocator, filename, 1024);
    defer allocator.free(content);

    // Parse bundle and extract private key
    // Implementation depends on bundle format
    return try zledger.zsig.Keypair.fromPrivateKeyBase64(private_key_b64);
}
```
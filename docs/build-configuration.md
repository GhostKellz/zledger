# Build Configuration

Zledger uses a flexible build system that allows you to include only the components you need, reducing binary size and compile time.

## Available Build Options

| Option | Default | Description |
|--------|---------|-------------|
| `--zsig` | `true` | Enable Zsig cryptographic signing functionality |
| `--ledger` | `true` | Enable core ledger functionality |
| `--contracts` | `true` | Enable smart contract functionality |
| `--crypto-storage` | `true` | Enable encrypted storage functionality |
| `--wallet` | `true` | Enable wallet integration functionality |

## Build Examples

### Full Build (All Features)
```bash
zig build
# or explicitly
zig build -Dzsig=true -Dledger=true -Dcontracts=true -Dcrypto-storage=true -Dwallet=true
```

### Minimal Ledger Only
```bash
zig build -Dledger=true -Dzsig=false -Dcontracts=false -Dcrypto-storage=false -Dwallet=false
```

### Cryptographic Library Only
```bash
zig build -Dzsig=true -Dcrypto-storage=true -Dledger=false -Dcontracts=false -Dwallet=false
```

### Smart Contracts with Ledger
```bash
zig build -Dledger=true -Dcontracts=true -Dzsig=false -Dcrypto-storage=false -Dwallet=false
```

### Wallet with Signing
```bash
zig build -Dwallet=true -Dzsig=true -Dledger=false -Dcontracts=false -Dcrypto-storage=false
```

## Build Size Comparison

| Configuration | Estimated Size | Use Case |
|---------------|----------------|----------|
| Full build | ~850KB | Complete financial platform |
| Ledger only | ~320KB | Simple accounting |
| Zsig only | ~180KB | Cryptographic operations |
| Contracts + Ledger | ~580KB | Smart contract platform |
| Wallet + Zsig | ~240KB | Cryptocurrency wallet |

## Dependencies

- **zcrypto**: Only included when `zsig`, `crypto-storage`, or `wallet` are enabled
- **std**: Always included (Zig standard library)

## Integration in Your Project

Add Zledger to your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // ... your build setup ...

    const zledger = b.dependency("zledger", .{
        .zsig = true,           // Enable cryptographic signing
        .ledger = true,         // Enable ledger functionality
        .contracts = false,     // Disable smart contracts
        .crypto_storage = true, // Enable encrypted storage
        .wallet = false,        // Disable wallet integration
    });

    exe.root_module.addImport("zledger", zledger.module("zledger"));
}
```

## Runtime Feature Detection

You can check which features are enabled at compile time:

```zig
const zledger = @import("zledger");
const build_options = @import("build_options");

pub fn main() !void {
    if (build_options.enable_ledger) {
        // Ledger functionality available
        const ledger = zledger.Ledger.init();
    }

    if (build_options.enable_zsig) {
        // Cryptographic signing available
        const keypair = try zledger.generateKeypair();
    }

    if (build_options.enable_contracts) {
        // Smart contracts available
        const contract = zledger.Contract.init();
    }
}
```

## Testing Configurations

Run tests for specific configurations:

```bash
# Test full build
zig build test

# Test ledger-only build
zig build test -Dledger=true -Dzsig=false -Dcontracts=false -Dcrypto-storage=false -Dwallet=false
```
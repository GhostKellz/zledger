//! Distributed Ledger Example
//! This example demonstrates Zledger features that could integrate with
//! distributed systems like Keystone, including:
//! - Journal replay capabilities
//! - State synchronization
//! - Identity-aware transactions
//! - Audit trail for distributed systems

const std = @import("std");
const zledger = @import("zledger");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Zledger Distributed Systems Example ===\n\n");

    // Create a distributed-aware ledger with journal replay capabilities
    var node_ledger = zledger.Ledger.init(allocator);
    defer node_ledger.deinit();

    // Set node identity
    const node_id = "node-alice-001";
    try node_ledger.setNodeIdentity(node_id);

    std.debug.print("Initialized ledger for distributed node: {s}\n", .{node_id});

    // Create accounts for different nodes in the distributed system
    const node_alice = try node_ledger.createAccount(.{
        .name = "Node Alice Balance",
        .account_type = .Assets,
        .metadata = .{ .node_id = "alice", .role = "validator" },
    });

    const node_bob = try node_ledger.createAccount(.{
        .name = "Node Bob Balance",
        .account_type = .Assets,
        .metadata = .{ .node_id = "bob", .role = "executor" },
    });

    const gas_pool = try node_ledger.createAccount(.{
        .name = "Gas Pool",
        .account_type = .Revenue,
        .metadata = .{ .purpose = "execution_fees" },
    });

    // Demonstrate identity-aware transaction creation
    std.debug.print("\n=== Identity-Aware Transactions ===\n");

    // Generate identity keypairs for each node
    const alice_identity = try zledger.generateKeypair();
    const bob_identity = try zledger.generateKeypair();

    // Create a signed transaction for distributed consensus
    var dist_tx = zledger.Transaction.init(allocator);
    defer dist_tx.deinit();

    try dist_tx.setDescription("Distributed execution fee payment");
    try dist_tx.setIdentity(alice_identity.public_key);

    // Add transaction entries
    try dist_tx.addEntry(.{
        .account_id = node_alice,
        .amount = zledger.FixedPoint.fromFloat(10.00),
        .debit = false, // Credit (paying out)
        .metadata = .{
            .execution_id = "exec-12345",
            .node_id = "alice",
        },
    });

    try dist_tx.addEntry(.{
        .account_id = gas_pool,
        .amount = zledger.FixedPoint.fromFloat(10.00),
        .debit = true, // Debit (receiving)
    });

    // Sign the transaction for authenticity
    const tx_data = try dist_tx.serialize(allocator);
    defer allocator.free(tx_data);
    const tx_signature = try zledger.signMessage(alice_identity, tx_data);
    try dist_tx.setSignature(tx_signature);

    // Post the signed transaction
    try node_ledger.postTransaction(&dist_tx);
    std.debug.print("Posted signed transaction from node Alice\n");

    // Demonstrate journal replay for state synchronization
    std.debug.print("\n=== Journal Replay for State Sync ===\n");

    // Create multiple transactions to build up state
    const transactions = [_]struct { from: []const u8, to: []const u8, amount: f64, identity: zledger.Keypair }{
        .{ .from = "Node Bob Balance", .to = "Gas Pool", .amount = 25.00, .identity = bob_identity },
        .{ .from = "Node Alice Balance", .to = "Gas Pool", .amount = 15.50, .identity = alice_identity },
        .{ .from = "Node Bob Balance", .to = "Gas Pool", .amount = 8.75, .identity = bob_identity },
    };

    var journal_entries = std.ArrayList(zledger.JournalEntry).init(allocator);
    defer journal_entries.deinit();

    for (transactions, 0..) |tx_data, i| {
        var tx = zledger.Transaction.init(allocator);
        defer tx.deinit();

        try tx.setDescription("Distributed system transaction");
        try tx.setIdentity(tx_data.identity.public_key);

        const from_account = if (std.mem.eql(u8, tx_data.from, "Node Alice Balance"))
            node_alice
        else
            node_bob;

        try tx.addEntry(.{
            .account_id = from_account,
            .amount = zledger.FixedPoint.fromFloat(tx_data.amount),
            .debit = false,
        });

        try tx.addEntry(.{
            .account_id = gas_pool,
            .amount = zledger.FixedPoint.fromFloat(tx_data.amount),
            .debit = true,
        });

        // Sign and post
        const serialized = try tx.serialize(allocator);
        defer allocator.free(serialized);
        const signature = try zledger.signMessage(tx_data.identity, serialized);
        try tx.setSignature(signature);

        try node_ledger.postTransaction(&tx);

        // Record in journal for replay
        const journal_entry = try node_ledger.getLastJournalEntry();
        try journal_entries.append(journal_entry);

        std.debug.print("Transaction {}: {s} -> {s}: ${d:.2}\n", .{
            i + 1,
            tx_data.from,
            tx_data.to,
            tx_data.amount,
        });
    }

    // Simulate state synchronization using journal replay
    std.debug.print("\n=== State Synchronization Simulation ===\n");

    // Create a new "replica" ledger
    var replica_ledger = zledger.Ledger.init(allocator);
    defer replica_ledger.deinit();

    try replica_ledger.setNodeIdentity("node-replica-002");

    // Recreate accounts on replica
    const replica_alice = try replica_ledger.createAccount(.{
        .name = "Node Alice Balance",
        .account_type = .Assets,
        .metadata = .{ .node_id = "alice", .role = "validator" },
    });

    const replica_bob = try replica_ledger.createAccount(.{
        .name = "Node Bob Balance",
        .account_type = .Assets,
        .metadata = .{ .node_id = "bob", .role = "executor" },
    });

    const replica_gas = try replica_ledger.createAccount(.{
        .name = "Gas Pool",
        .account_type = .Revenue,
        .metadata = .{ .purpose = "execution_fees" },
    });

    // Replay journal entries to synchronize state
    std.debug.print("Replaying {} journal entries...\n", .{journal_entries.items.len});

    for (journal_entries.items) |entry| {
        try replica_ledger.replayJournalEntry(entry);
    }

    std.debug.print("State synchronization complete\n");

    // Verify both ledgers have the same state
    const original_alice_balance = try node_ledger.getAccountBalance(node_alice);
    const replica_alice_balance = try replica_ledger.getAccountBalance(replica_alice);

    const original_gas_balance = try node_ledger.getAccountBalance(gas_pool);
    const replica_gas_balance = try replica_ledger.getAccountBalance(replica_gas);

    std.debug.print("\n=== State Verification ===\n");
    std.debug.print("Original Alice Balance: ${d:.2}\n", .{original_alice_balance.toFloat()});
    std.debug.print("Replica Alice Balance: ${d:.2}\n", .{replica_alice_balance.toFloat()});
    std.debug.print("Balances Match: {}\n", .{original_alice_balance.equals(replica_alice_balance)});

    std.debug.print("Original Gas Pool: ${d:.2}\n", .{original_gas_balance.toFloat()});
    std.debug.print("Replica Gas Pool: ${d:.2}\n", .{replica_gas_balance.toFloat()});
    std.debug.print("Gas Pools Match: {}\n", .{original_gas_balance.equals(replica_gas_balance)});

    // Generate comprehensive audit report for distributed system compliance
    std.debug.print("\n=== Distributed System Audit ===\n");

    var auditor = zledger.Auditor.init(allocator);
    defer auditor.deinit();

    const audit_report = try auditor.generateDistributedReport(&node_ledger);
    defer audit_report.deinit();

    std.debug.print("Node ID: {s}\n", .{audit_report.node_id});
    std.debug.print("Total Signed Transactions: {}\n", .{audit_report.signed_transaction_count});
    std.debug.print("Identity Verification Rate: {d:.1}%\n", .{audit_report.identity_verification_rate * 100});
    std.debug.print("Consensus Ready: {}\n", .{audit_report.consensus_ready});
    std.debug.print("Merkle Root: {}\n", .{std.fmt.fmtSliceHexUpper(&audit_report.merkle_root)});

    std.debug.print("\n=== Distributed Example Complete ===\n");
}
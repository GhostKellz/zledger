//! Basic Ledger Example
//! This example demonstrates core ledger functionality including:
//! - Creating accounts
//! - Recording transactions
//! - Generating reports

const std = @import("std");
const zledger = @import("zledger");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Zledger Basic Example ===\n\n");

    // Initialize ledger
    var ledger = zledger.Ledger.init(allocator);
    defer ledger.deinit();

    // Create accounts for a small business
    const cash = try ledger.createAccount(.{
        .name = "Cash",
        .account_type = .Assets,
    });

    const accounts_receivable = try ledger.createAccount(.{
        .name = "Accounts Receivable",
        .account_type = .Assets,
    });

    const revenue = try ledger.createAccount(.{
        .name = "Sales Revenue",
        .account_type = .Revenue,
    });

    const expenses = try ledger.createAccount(.{
        .name = "Office Expenses",
        .account_type = .Expenses,
    });

    const owner_equity = try ledger.createAccount(.{
        .name = "Owner's Equity",
        .account_type = .Equity,
    });

    std.debug.print("Created accounts:\n");
    std.debug.print("- Cash (Assets)\n");
    std.debug.print("- Accounts Receivable (Assets)\n");
    std.debug.print("- Sales Revenue (Revenue)\n");
    std.debug.print("- Office Expenses (Expenses)\n");
    std.debug.print("- Owner's Equity (Equity)\n\n");

    // Transaction 1: Initial investment
    {
        var tx1 = zledger.Transaction.init(allocator);
        defer tx1.deinit();

        try tx1.setDescription("Initial owner investment");

        try tx1.addEntry(.{
            .account_id = cash,
            .amount = zledger.FixedPoint.fromFloat(10000.00),
            .debit = true,
        });

        try tx1.addEntry(.{
            .account_id = owner_equity,
            .amount = zledger.FixedPoint.fromFloat(10000.00),
            .debit = false,
        });

        try ledger.postTransaction(&tx1);
        std.debug.print("Posted: Initial investment of $10,000\n");
    }

    // Transaction 2: Make a sale on credit
    {
        var tx2 = zledger.Transaction.init(allocator);
        defer tx2.deinit();

        try tx2.setDescription("Sale to customer on credit");

        try tx2.addEntry(.{
            .account_id = accounts_receivable,
            .amount = zledger.FixedPoint.fromFloat(2500.00),
            .debit = true,
        });

        try tx2.addEntry(.{
            .account_id = revenue,
            .amount = zledger.FixedPoint.fromFloat(2500.00),
            .debit = false,
        });

        try ledger.postTransaction(&tx2);
        std.debug.print("Posted: Sale on credit for $2,500\n");
    }

    // Transaction 3: Pay office expenses
    {
        var tx3 = zledger.Transaction.init(allocator);
        defer tx3.deinit();

        try tx3.setDescription("Paid monthly office rent");

        try tx3.addEntry(.{
            .account_id = expenses,
            .amount = zledger.FixedPoint.fromFloat(800.00),
            .debit = true,
        });

        try tx3.addEntry(.{
            .account_id = cash,
            .amount = zledger.FixedPoint.fromFloat(800.00),
            .debit = false,
        });

        try ledger.postTransaction(&tx3);
        std.debug.print("Posted: Office rent payment of $800\n");
    }

    // Transaction 4: Collect receivable
    {
        var tx4 = zledger.Transaction.init(allocator);
        defer tx4.deinit();

        try tx4.setDescription("Received payment from customer");

        try tx4.addEntry(.{
            .account_id = cash,
            .amount = zledger.FixedPoint.fromFloat(1500.00),
            .debit = true,
        });

        try tx4.addEntry(.{
            .account_id = accounts_receivable,
            .amount = zledger.FixedPoint.fromFloat(1500.00),
            .debit = false,
        });

        try ledger.postTransaction(&tx4);
        std.debug.print("Posted: Received $1,500 from customer\n\n");
    }

    // Generate account balances
    std.debug.print("=== Account Balances ===\n");
    const cash_balance = try ledger.getAccountBalance(cash);
    const ar_balance = try ledger.getAccountBalance(accounts_receivable);
    const revenue_balance = try ledger.getAccountBalance(revenue);
    const expense_balance = try ledger.getAccountBalance(expenses);
    const equity_balance = try ledger.getAccountBalance(owner_equity);

    std.debug.print("Cash: ${d:.2}\n", .{cash_balance.toFloat()});
    std.debug.print("Accounts Receivable: ${d:.2}\n", .{ar_balance.toFloat()});
    std.debug.print("Sales Revenue: ${d:.2}\n", .{revenue_balance.toFloat()});
    std.debug.print("Office Expenses: ${d:.2}\n", .{expense_balance.toFloat()});
    std.debug.print("Owner's Equity: ${d:.2}\n", .{equity_balance.toFloat()});

    // Verify accounting equation: Assets = Liabilities + Equity
    const total_assets = cash_balance.add(ar_balance);
    const net_income = revenue_balance.subtract(expense_balance);
    const total_equity = equity_balance.add(net_income);

    std.debug.print("\n=== Accounting Equation Check ===\n");
    std.debug.print("Total Assets: ${d:.2}\n", .{total_assets.toFloat()});
    std.debug.print("Total Equity + Net Income: ${d:.2}\n", .{total_equity.toFloat()});
    std.debug.print("Balanced: {}\n", .{total_assets.equals(total_equity)});

    // Generate audit report
    var auditor = zledger.Auditor.init(allocator);
    defer auditor.deinit();

    const audit_report = try auditor.generateReport(&ledger);
    defer audit_report.deinit();

    std.debug.print("\n=== Audit Summary ===\n");
    std.debug.print("Total Transactions: {}\n", .{audit_report.transaction_count});
    std.debug.print("All Transactions Balanced: {}\n", .{audit_report.all_balanced});
    std.debug.print("Audit Status: {s}\n", .{if (audit_report.passed) "PASSED" else "FAILED"});
}
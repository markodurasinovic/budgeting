import SwiftUI
import SwiftData
import BudgetingKit

struct MonthlyOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.item)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    @Query(sort: [SortDescriptor(\MonthlyBudget.year), SortDescriptor(\MonthlyBudget.month)])
    private var budgets: [MonthlyBudget]

    @State private var selectedMonth = Date()
    @State private var showingBudgetEdit = false

    private var month: Int {
        Calendar.current.component(.month, from: selectedMonth)
    }

    private var year: Int {
        Calendar.current.component(.year, from: selectedMonth)
    }

    private var monthName: String {
        selectedMonth.formatted(.dateTime.year().month(.wide))
    }

    private var currentBudget: MonthlyBudget {
        BudgetStore.budgetForMonth(month, year: year, context: modelContext)
    }

    private var expenses: Decimal {
        BudgetStore.totalForMonth(entries, month: month, year: year)
    }

    private var remainder: Decimal {
        BudgetStore.remainder(income: currentBudget.income, expenses: expenses, bills: currentBudget.bills, savings: currentBudget.savings, investment: currentBudget.investment)
    }

    private var savingsRate: Decimal? {
        BudgetStore.savingsRate(savings: currentBudget.savings, investment: currentBudget.investment, income: currentBudget.income, remainder: remainder)
    }

    private var runningTotal: Decimal {
        let pastBudgets = budgets.filter { $0.year < year || ($0.year == year && $0.month <= month) }
        let monthExpenses = pastBudgets.map { b in
            (month: b.month, year: b.year, total: BudgetStore.totalForMonth(entries, month: b.month, year: b.year))
        }
        return BudgetStore.runningTotalSavings(budgets: pastBudgets, expensesByMonth: monthExpenses)
    }

    var body: some View {
        NavigationStack {
            let tagTotals = BudgetStore.totalsByTagForMonth(entries, month: month, year: year)
            let monthEntries = BudgetStore.entriesForMonth(entries, month: month, year: year)

            List {
                Section(monthName) {
                    HStack {
                        Text("Income")
                            .font(.headline)
                        Spacer()
                        Text(MoneyHelper.format(currentBudget.income))
                            .font(.headline)
                    }

                    HStack {
                        Text("Expenses")
                            .font(.subheadline)
                        Spacer()
                        Text(MoneyHelper.format(expenses))
                            .font(.subheadline)
                            .foregroundStyle(expenses < 0 ? .green : .primary)
                    }

                    HStack {
                        Text("Remainder")
                            .font(.headline)
                        Spacer()
                        Text(MoneyHelper.format(remainder))
                            .font(.headline)
                            .foregroundStyle(remainder < 0 ? .red : .green)
                    }

                    HStack {
                        Text("Entries")
                            .font(.subheadline)
                        Spacer()
                        Text("\(monthEntries.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Budget") {
                    HStack {
                        Text("Bills")
                        Spacer()
                        Text(MoneyHelper.format(currentBudget.bills))
                    }
                    HStack {
                        Text("Savings")
                        Spacer()
                        Text(MoneyHelper.format(currentBudget.savings))
                    }
                    HStack {
                        Text("Investment")
                        Spacer()
                        Text(MoneyHelper.format(currentBudget.investment))
                    }
                    HStack {
                        Text("Savings rate")
                        Spacer()
                        if let rate = savingsRate {
                            Text(String(format: "%.1f%%", NSDecimalNumber(decimal: rate * 100).doubleValue))
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text("Running total saved")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(MoneyHelper.format(runningTotal))
                            .fontWeight(.semibold)
                    }
                }

                Section("By tag") {
                    if tagTotals.isEmpty {
                        Text("No entries this month")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(tagTotals, id: \.tag) { item in
                        HStack {
                            Circle()
                                .fill(Color.hex(item.tag, from: BudgetStore.tagColorHex(tags, for: item.tag)))
                                .frame(width: 12, height: 12)
                            Text(item.tag)
                            Spacer()
                            Text(MoneyHelper.format(item.total))
                                .foregroundStyle(item.total < 0 ? .red : .primary)
                        }
                    }
                }

                Section("Recent entries") {
                    let recent = Array(monthEntries.prefix(5))
                    if recent.isEmpty {
                        Text("No entries this month")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(recent, id: \.id) { entry in
                        EntryRowView(entry: entry)
                    }
                }
            }
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonthPicker(selection: $selectedMonth)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingBudgetEdit = true
                    } label: {
                        Label("Budget", systemImage: "pencil")
                    }
                }
            }
            .sheet(isPresented: $showingBudgetEdit) {
                BudgetEditView(budget: currentBudget)
            }
        }
    }
}

#Preview {
    MonthlyOverviewView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
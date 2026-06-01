import SwiftUI
import SwiftData
import BudgetingKit

struct DetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.item)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    @Query(sort: [SortDescriptor(\MonthlyBudget.year), SortDescriptor(\MonthlyBudget.month)])
    private var budgets: [MonthlyBudget]

    let month: Int
    let year: Int
    let selectedTag: String?
    let onAddEntry: () -> Void
    let onEditEntry: (Entry) -> Void

    @State private var searchText = ""
    @State private var selectedEntries: Set<Entry.ID> = []
    @State private var showingBudgetEdit = false

    private var effectiveTag: String? {
        if let tag = selectedTag, tag != "___ALL___" { return tag }
        return nil
    }

    private var filteredEntries: [Entry] {
        let monthEntries = BudgetStore.entriesForMonth(entries, month: month, year: year)
        let tagged: [Entry]
        if let tag = effectiveTag {
            tagged = monthEntries.filter { $0.tag == tag }
        } else {
            tagged = monthEntries
        }
        return BudgetStore.searchEntries(tagged, query: searchText)
    }

    private var total: Decimal {
        filteredEntries.reduce(Decimal(0)) { $0 + $1.amount }
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

    private var savingsRateValue: Decimal? {
        BudgetStore.savingsRate(savings: currentBudget.savings, investment: currentBudget.investment, income: currentBudget.income, remainder: remainder)
    }

    private var runningTotal: Decimal {
        let pastBudgets = budgets.filter { $0.year < year || ($0.year == year && $0.month <= month) }
        let monthExpenses = pastBudgets.map { b in
            (month: b.month, year: b.year, total: BudgetStore.totalForMonth(entries, month: b.month, year: b.year))
        }
        return BudgetStore.runningTotalSavings(budgets: pastBudgets, expensesByMonth: monthExpenses)
    }

    private var previousRunningTotal: Decimal {
        let prevBudgets = budgets.filter { $0.year < year || ($0.year == year && $0.month < month) }
        let monthExpenses = prevBudgets.map { b in
            (month: b.month, year: b.year, total: BudgetStore.totalForMonth(entries, month: b.month, year: b.year))
        }
        return BudgetStore.runningTotalSavings(budgets: prevBudgets, expensesByMonth: monthExpenses)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            budgetBar
            Divider()
            if filteredEntries.isEmpty {
                emptyState
            } else {
                entryTable
            }
        }
        .searchable(text: $searchText, prompt: "Search entries")
        .navigationTitle(effectiveTag ?? "All Entries")
        .sheet(isPresented: $showingBudgetEdit) {
            MacBudgetEditView(budget: currentBudget)
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(effectiveTag ?? "All Entries")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(MoneyHelper.format(total))
                    .font(.title3)
                    .foregroundStyle(total < 0 ? .red : .secondary)
            }
            Spacer()
            Button {
                showingBudgetEdit = true
            } label: {
                Label("Budget", systemImage: "pencil.line")
            }
            .buttonStyle(.bordered)
            Button {
                onAddEntry()
            } label: {
                Label("Add Entry", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var budgetBar: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Income")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(MoneyHelper.format(currentBudget.income))
                    .font(.body)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Bills")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(MoneyHelper.format(currentBudget.bills))
                    .font(.body)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Expenses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(MoneyHelper.format(expenses))
                    .font(.body)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Remainder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(MoneyHelper.format(remainder))
                    .font(.body)
                    .foregroundStyle(remainder < 0 ? .red : .green)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Savings rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let rate = savingsRateValue {
                    Text(String(format: "%.1f%%", NSDecimalNumber(decimal: rate * 100).doubleValue))
                        .font(.body)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Total saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(MoneyHelper.format(runningTotal))
                    .font(.body)
                    .fontWeight(.semibold)
                let delta = runningTotal - previousRunningTotal
                Text("\(delta >= 0 ? "+" : "")\(MoneyHelper.format(delta))")
                    .font(.caption)
                    .foregroundStyle(delta >= 0 ? .green : .red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No entries",
            systemImage: "tray",
            description: Text("Add an entry to get started")
        )
    }

    private var entryTable: some View {
        Table(filteredEntries, selection: $selectedEntries) {
            TableColumn("Date") { entry in
                Text(entry.date.formatted(.dateTime.day().month(.abbreviated)))
                    .onTapGesture(count: 2) {
                        onEditEntry(entry)
                    }
            }
            .width(min: 80)

            TableColumn("Item") { entry in
                Text(entry.item)
                    .onTapGesture(count: 2) {
                        onEditEntry(entry)
                    }
            }

            TableColumn("Tag") { entry in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.hex(entry.tag, from: BudgetStore.tagColorHex(tags, for: entry.tag)))
                        .frame(width: 8, height: 8)
                    Text(entry.tag)
                }
                .onTapGesture(count: 2) {
                    onEditEntry(entry)
                }
            }

            TableColumn("Amount") { entry in
                Text(MoneyHelper.format(entry.amount))
                    .foregroundStyle(entry.amount < 0 ? .red : .primary)
                    .onTapGesture(count: 2) {
                        onEditEntry(entry)
                    }
            }
            .width(min: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: Entry.ID.self) { items in
            Button("Delete", systemImage: "trash") {
                deleteSelected(items)
            }
        }
        .onDeleteCommand {
            deleteSelected(selectedEntries)
        }
    }

    private func deleteSelected(_ ids: Set<Entry.ID>) {
        let toDelete = filteredEntries.filter { ids.contains($0.id) }
        BudgetStore.deleteEntries(toDelete, context: modelContext)
    }
}

#Preview {
    DetailView(month: 5, year: 2026, selectedTag: nil, onAddEntry: {}, onEditEntry: { _ in })
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
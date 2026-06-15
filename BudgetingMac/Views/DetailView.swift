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
    let onAddEntry: (Date?) -> Void
    let onEditEntry: (Entry) -> Void

    @State private var searchText = ""
    @State private var selectedEntries: Set<Entry.ID> = []
    @State private var showingBudgetEdit = false

    private var selectedEntryDate: Date? {
        guard let firstID = selectedEntries.first else { return nil }
        return filteredEntries.first(where: { $0.id == firstID })?.date
    }

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

    private var daysRemaining: Int {
        let totalDays = BudgetStore.daysInMonth(month: month, year: year)
        let elapsed = BudgetStore.daysElapsedInMonth(month: month, year: year)
        return max(totalDays - elapsed, 0)
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

    private func colorForTag(_ tagName: String) -> Color {
        Color.hex(tagName, from: BudgetStore.tagColorHex(tags, for: tagName))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            summaryBar
            Divider()
            if filteredEntries.isEmpty {
                emptyState
            } else {
                entryTable
            }
        }
        .searchable(text: $searchText, prompt: "Search entries")
        .navigationTitle(effectiveTag ?? "All Entries")
        .toolbar {
            ToolbarItem {
                Button {
                    showingBudgetEdit = true
                } label: {
                    Label("Edit Budget", systemImage: "pencil.line")
                }
            }
            ToolbarItem {
                Button {
                    onAddEntry(selectedEntryDate ?? Date())
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showingBudgetEdit) {
            MacBudgetEditView(budget: currentBudget)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(effectiveTag ?? "All Entries")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(MoneyHelper.format(total))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(total < 0 ? Color.red : Color.primary)
            }
            Spacer()
            if !tagTotals.isEmpty {
                miniAllocation
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var miniAllocation: some View {
        let items = tagTotals.filter { $0.total != 0 }
        let totalAbs = items.map(\.total).map(abs).reduce(Decimal(0), +)
        return VStack(alignment: .trailing, spacing: 4) {
            if totalAbs > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(items.prefix(8), id: \.tag) { item in
                            let width = geo.size.width * CGFloat(truncating: NSDecimalNumber(decimal: abs(item.total) / totalAbs))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorForTag(item.tag))
                                .frame(width: max(width, 3))
                        }
                    }
                }
                .frame(width: 120, height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            Text("\(filteredEntries.count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120)
    }

    private var summaryBar: some View {
        HStack(spacing: 0) {
            summaryCell("Income", value: currentBudget.income, icon: "banknote.fill", color: .green)
            Divider()
            summaryCell("Bills", value: currentBudget.bills, icon: "doc.text.fill", color: .orange)
            Divider()
            summaryCell("Expenses", value: expenses, icon: "cart.fill", color: .red)
            Divider()
            summaryCell("Remainder", value: remainder, icon: remainder >= 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill", color: remainder >= 0 ? .green : .red, highlight: true, subtitle: daysRemaining > 0 && remainder != 0 ? "\(MoneyHelper.format(remainder / Decimal(daysRemaining))) / day" : nil)
            Divider()
            VStack(alignment: .center, spacing: 2) {
                if let rate = savingsRateValue {
                    Text(String(format: "%.1f%%", NSDecimalNumber(decimal: rate * 100).doubleValue))
                        .font(.body)
                        .fontWeight(.semibold)
                    Text("Savings rate")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                    Text("Savings rate")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            Divider()
            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyHelper.format(runningTotal))
                    .font(.body)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                let delta = runningTotal - previousRunningTotal
                Text("\(delta >= 0 ? "+" : "")\(MoneyHelper.format(delta))")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(delta >= 0 ? Color.green : Color.red)
                Text("Total saved")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func summaryCell(_ label: String, value: Decimal, icon: String, color: Color, highlight: Bool = false, subtitle: String? = nil) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(MoneyHelper.format(value))
                    .font(highlight ? .body : .callout)
                    .fontWeight(highlight ? .bold : .medium)
                    .monospacedDigit()
                    .foregroundStyle(highlight ? color : (value < 0 ? Color.red : Color.primary))
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
                        .fill(colorForTag(entry.tag))
                        .frame(width: 8, height: 8)
                    Text(entry.tag)
                }
                .onTapGesture(count: 2) {
                    onEditEntry(entry)
                }
            }

            TableColumn("Amount") { entry in
                Text(MoneyHelper.format(entry.amount))
                    .foregroundStyle(entry.amount < 0 ? Color.red : Color.primary)
                    .monospacedDigit()
                    .onTapGesture(count: 2) {
                        onEditEntry(entry)
                    }
            }
            .width(min: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: Entry.ID.self) { items in
            if let id = items.first, items.count == 1,
               let entry = filteredEntries.first(where: { $0.id == id }) {
                Button("Edit", systemImage: "pencil") {
                    onEditEntry(entry)
                }
            }
            Button("Delete", systemImage: "trash") {
                deleteSelected(items)
            }
        }
        .onDeleteCommand {
            deleteSelected(selectedEntries)
        }
    }

    private var tagTotals: [(tag: String, total: Decimal)] {
        let monthEntries = BudgetStore.entriesForMonth(entries, month: month, year: year)
        var totals: [String: Decimal] = [:]
        for entry in monthEntries {
            totals[entry.tag, default: Decimal(0)] += entry.amount
        }
        return totals.sorted { abs($0.value) > abs($1.value) }.map { (tag: $0.key, total: $0.value) }
    }

    private func deleteSelected(_ ids: Set<Entry.ID>) {
        let toDelete = filteredEntries.filter { ids.contains($0.id) }
        BudgetStore.deleteEntries(toDelete, context: modelContext)
    }
}

#Preview {
    DetailView(month: 5, year: 2026, selectedTag: nil, onAddEntry: { _ in }, onEditEntry: { _ in })
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
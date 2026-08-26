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

    struct Snapshot {
        let filteredEntries: [Entry]
        let monthEntries: [Entry]
        let total: Decimal
        let expenses: Decimal
        let remainder: Decimal
        let carryover: Decimal
        let adjustedRemainder: Decimal
        let daysRemaining: Int
        let savingsRate: Decimal?
        let tagTotals: [(tag: String, total: Decimal)]
        let currentBudget: MonthlyBudget
        let runningTotal: Decimal
        let previousRunningTotal: Decimal
        let tagColors: [String: Color]
    }

    private var selectedEntryDate: Date? {
        guard let firstID = selectedEntries.first else { return nil }
        return snapshot.filteredEntries.first(where: { $0.id == firstID })?.date
    }

    private var effectiveTag: String? {
        if let tag = selectedTag, tag != "___ALL___" { return tag }
        return nil
    }

    private var snapshot: Snapshot {
        let cal = Calendar.current
        let effective = effectiveTag
        let query = searchText
        let lowerQuery = query.lowercased()

        var monthExpenseMap: [Int: Decimal] = [:]
        var monthEntries: [Entry] = []
        var tagTotals: [String: Decimal] = [:]
        var filtered: [Entry] = []

        for e in entries {
            let comps = cal.dateComponents([.month, .year], from: e.date)
            let eMonth = comps.month ?? 0
            let eYear = comps.year ?? 0
            let key = eYear &* 100 &+ eMonth
            monthExpenseMap[key, default: Decimal(0)] += e.amount

            let isCurrentMonth = eMonth == month && eYear == year
            guard isCurrentMonth else { continue }

            monthEntries.append(e)
            tagTotals[e.tag, default: Decimal(0)] += e.amount

            let matchesTag: Bool
            if let effective {
                matchesTag = e.tag == effective
            } else {
                matchesTag = true
            }
            guard matchesTag else { continue }

            if query.isEmpty {
                filtered.append(e)
            } else if e.item.lowercased().contains(lowerQuery) || e.tag.lowercased().contains(lowerQuery) {
                filtered.append(e)
            }
        }

        let total = filtered.reduce(Decimal(0)) { $0 + $1.amount }
        let expenses = monthExpenseMap[year &* 100 &+ month] ?? Decimal(0)
        let sortedTagTotals = tagTotals.sorted { abs($0.value) > abs($1.value) }.map { (tag: $0.key, total: $0.value) }

        let currentBudget = BudgetStore.budgetForMonth(month, year: year, context: modelContext)
        let remainder = BudgetStore.remainder(income: currentBudget.income, expenses: expenses, bills: currentBudget.bills, savings: currentBudget.savings, investment: currentBudget.investment)
        let carryover = BudgetStore.carryover(month: month, year: year, entries: entries, budgets: budgets)
        let daysRemaining = BudgetStore.daysRemainingInMonth(month: month, year: year)
        let savingsRate = BudgetStore.savingsRate(savings: currentBudget.savings, investment: currentBudget.investment, income: currentBudget.income, remainder: remainder)

        let targetCutoff = year &* 100 &+ month
        var runningTotal = Decimal(0)
        var previousRunningTotal = Decimal(0)
        for budget in budgets {
            let k = budget.year &* 100 &+ budget.month
            let exp = monthExpenseMap[k] ?? Decimal(0)
            let rem = budget.income - exp - budget.bills - budget.savings - budget.investment
            let contribution = budget.savings + budget.investment + rem
            if k <= targetCutoff {
                runningTotal += contribution
            }
            if k < targetCutoff {
                previousRunningTotal += contribution
            }
        }

        var tagColors: [String: Color] = [:]
        for tag in tags {
            tagColors[tag.name] = Color.hex(tag.name, from: BudgetStore.tagColorHex(tags, for: tag.name))
        }

        return Snapshot(
            filteredEntries: filtered,
            monthEntries: monthEntries,
            total: total,
            expenses: expenses,
            remainder: remainder,
            carryover: carryover,
            adjustedRemainder: remainder + carryover,
            daysRemaining: daysRemaining,
            savingsRate: savingsRate,
            tagTotals: sortedTagTotals,
            currentBudget: currentBudget,
            runningTotal: runningTotal,
            previousRunningTotal: previousRunningTotal,
            tagColors: tagColors
        )
    }

    private func colorForTag(_ tagName: String, snap: Snapshot) -> Color {
        snap.tagColors[tagName] ?? Color.hex(tagName, from: nil)
    }

    var body: some View {
        let snap = snapshot
        return VStack(spacing: 0) {
            headerBar(snap)
            summaryBar(snap)
            Divider()
            if snap.filteredEntries.isEmpty {
                emptyState
            } else {
                entryTable(snap)
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
            MacBudgetEditView(budget: snap.currentBudget)
                .onDisappear {
                    BudgetingContainer.scheduleWidgetRefresh(context: modelContext)
                }
        }
    }

    private func headerBar(_ snap: Snapshot) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(MoneyHelper.format(snap.adjustedRemainder))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(snap.adjustedRemainder >= 0 ? Color.green : Color.red)
                if snap.daysRemaining > 0 && snap.adjustedRemainder != 0 {
                    Text("\(MoneyHelper.format(snap.adjustedRemainder / Decimal(snap.daysRemaining))) / day")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if snap.carryover != 0 {
                    let previous = PortfolioStore.previousMonth(for: month, year: year)
                    Text("\(MoneyHelper.format(snap.carryover)) carried over from \(Formatters.monthYearString(month: previous.month, year: previous.year))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(snap.carryover > 0 ? .green : .red)
                }
            }
            Spacer()
            if !snap.tagTotals.isEmpty {
                miniAllocation(snap)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func miniAllocation(_ snap: Snapshot) -> some View {
        let items = snap.tagTotals.filter { $0.total != 0 }
        let totalAbs = items.map(\.total).map(abs).reduce(Decimal(0), +)
        return VStack(alignment: .trailing, spacing: 4) {
            if totalAbs > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(items.prefix(8), id: \.tag) { item in
                            let width = geo.size.width * CGFloat(truncating: NSDecimalNumber(decimal: abs(item.total) / totalAbs))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorForTag(item.tag, snap: snap))
                                .frame(width: max(width, 3))
                        }
                    }
                }
                .frame(width: 120, height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            Text("\(snap.filteredEntries.count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120)
    }

    private func summaryBar(_ snap: Snapshot) -> some View {
        HStack(spacing: 0) {
            summaryCell("Income", value: snap.currentBudget.income, icon: "banknote.fill", color: .green)
            Divider()
            summaryCell("Bills", value: snap.currentBudget.bills, icon: "doc.text.fill", color: .orange)
            Divider()
            summaryCell("Expenses", value: snap.expenses, icon: "cart.fill", color: .red)
            Divider()
            VStack(alignment: .center, spacing: 2) {
                if let rate = snap.savingsRate {
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
                Text(MoneyHelper.format(snap.runningTotal))
                    .font(.body)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                let delta = snap.runningTotal - snap.previousRunningTotal
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

    private func entryTable(_ snap: Snapshot) -> some View {
        Table(snap.filteredEntries, selection: $selectedEntries) {
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
                        .fill(colorForTag(entry.tag, snap: snap))
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
               let entry = snap.filteredEntries.first(where: { $0.id == id }) {
                Button("Edit", systemImage: "pencil") {
                    onEditEntry(entry)
                }
            }
            Button("Delete", systemImage: "trash") {
                deleteSelected(items, snapshot: snap)
            }
        }
        .onDeleteCommand {
            deleteSelected(selectedEntries, snapshot: snap)
        }
    }

    private func deleteSelected(_ ids: Set<Entry.ID>, snapshot snap: Snapshot) {
        let toDelete = snap.filteredEntries.filter { ids.contains($0.id) }
        BudgetStore.deleteEntries(toDelete, context: modelContext)
    }
}

#Preview {
    DetailView(month: 5, year: 2026, selectedTag: nil, onAddEntry: { _ in }, onEditEntry: { _ in })
        .modelContainer(BudgetingContainer.makePreviewContainer())
}

import SwiftUI
import SwiftData
import BudgetingKit

struct MacCategoryBreakdownView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.item)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    @Query(sort: [SortDescriptor(\MonthlyBudget.year), SortDescriptor(\MonthlyBudget.month)])
    private var budgets: [MonthlyBudget]

    let month: Int
    let year: Int

    struct Snapshot {
        let tagTotals: [(tag: String, total: Decimal)]
        let totalExpenses: Decimal
        let tagEntryCounts: [String: Int]
        let totalEntryCount: Int
        let currentBudget: MonthlyBudget
        let remainder: Decimal
        let carryover: Decimal
        let adjustedRemainder: Decimal
        let savingsRate: Decimal?
        let tagColors: [String: Color]
        let largestTag: String?
    }

    private var snapshot: Snapshot {
        let cal = Calendar.current
        var tagTotals: [String: Decimal] = [:]
        var tagEntryCounts: [String: Int] = [:]
        var totalEntryCount = 0
        for entry in entries {
            let comps = cal.dateComponents([.month, .year], from: entry.date)
            if comps.month == month && comps.year == year {
                tagTotals[entry.tag, default: Decimal(0)] += entry.amount
                tagEntryCounts[entry.tag, default: 0] += 1
                totalEntryCount += 1
            }
        }
        let sortedTagTotals = tagTotals.sorted { abs($0.value) > abs($1.value) }.map { (tag: $0.key, total: $0.value) }
        let totalExpenses = sortedTagTotals.reduce(Decimal(0)) { $0 + $1.total }
        let largestTag = sortedTagTotals.first?.tag

        let expenses = sortedTagTotals.reduce(Decimal(0)) { $0 + $1.total }
        let currentBudget = BudgetStore.budgetForMonth(month, year: year, context: modelContext)
        let remainder = BudgetStore.remainder(income: currentBudget.income, expenses: expenses, bills: currentBudget.bills, savings: currentBudget.savings, investment: currentBudget.investment)
        let carryover = BudgetStore.carryover(month: month, year: year, entries: entries, budgets: budgets)
        let savingsRate = BudgetStore.savingsRate(savings: currentBudget.savings, investment: currentBudget.investment, income: currentBudget.income, remainder: remainder)

        var tagColors: [String: Color] = [:]
        for tag in tags {
            tagColors[tag.name] = Color.hex(tag.name, from: BudgetStore.tagColorHex(tags, for: tag.name))
        }

        return Snapshot(
            tagTotals: sortedTagTotals,
            totalExpenses: totalExpenses,
            tagEntryCounts: tagEntryCounts,
            totalEntryCount: totalEntryCount,
            currentBudget: currentBudget,
            remainder: remainder,
            carryover: carryover,
            adjustedRemainder: remainder + carryover,
            savingsRate: savingsRate,
            tagColors: tagColors,
            largestTag: largestTag
        )
    }

    private func colorForTag(_ tagName: String, snap: Snapshot) -> Color {
        snap.tagColors[tagName] ?? Color.hex(tagName, from: nil)
    }

    var body: some View {
        let snap = snapshot
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                totalCard(snap)
                HStack(spacing: 16) {
                    budgetOverviewCard(snap)
                    savingsCard(snap)
                }
                allocationCard(snap)
                categoryBreakdownCard(snap)
            }
            .padding(20)
        }
        .navigationTitle("Categories")
    }

    private func totalCard(_ snap: Snapshot) -> some View {
        VStack(spacing: 12) {
            Text(Formatters.monthYearString(month: month, year: year))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(MoneyHelper.format(snap.totalExpenses))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(snap.totalExpenses < 0 ? Color.red : Color.primary)

            HStack(spacing: 16) {
                Label("\(snap.tagTotals.count) \(snap.tagTotals.count == 1 ? "category" : "categories")", systemImage: "tag.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label("\(snap.totalEntryCount) entries", systemImage: "list.bullet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func budgetOverviewCard(_ snap: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Budget", systemImage: "target")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            metricRow("Income", value: snap.currentBudget.income, icon: "banknote.fill", color: .green)
            metricRow("Bills", value: snap.currentBudget.bills, icon: "doc.text.fill", color: .orange)
            metricRow("Savings", value: snap.currentBudget.savings, icon: "leaf.fill", color: .blue)
            metricRow("Investment", value: snap.currentBudget.investment, icon: "chart.line.uptrend.xyaxis", color: .purple)
            if snap.carryover != 0 {
                metricRow("Carried over", value: snap.carryover, icon: "arrow.uturn.left.circle.fill", color: snap.carryover > 0 ? .green : .red)
            }

            Divider()

            metricRow("Remainder", value: snap.adjustedRemainder, icon: snap.adjustedRemainder >= 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill", color: snap.adjustedRemainder >= 0 ? .green : .red, accent: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func savingsCard(_ snap: Snapshot) -> some View {
        let savingsTotal = snap.currentBudget.savings + snap.currentBudget.investment + snap.remainder
        let savingsPct = snap.savingsRate.map { CGFloat(truncating: NSDecimalNumber(decimal: $0 * 100)) }

        return VStack(alignment: .leading, spacing: 14) {
            Label("Savings", systemImage: "leaf.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(MoneyHelper.format(savingsTotal))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(savingsTotal >= 0 ? Color.blue : Color.red)

                if let pct = savingsPct {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .quaternaryLabelColor))
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue)
                                .frame(width: geo.size.width * min(1, pct / 100), height: 12)
                        }
                    }
                    .frame(height: 12)

                    Text(String(format: "%.1f%% savings rate", pct))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .quaternaryLabelColor))
                        .frame(height: 12)
                    Text("Set income to see savings rate")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            metricRow("Savings", value: snap.currentBudget.savings, icon: "leaf.fill", color: .blue)
            metricRow("Investment", value: snap.currentBudget.investment, icon: "chart.line.uptrend.xyaxis", color: .purple)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func allocationCard(_ snap: Snapshot) -> some View {
        let items = snap.tagTotals.filter { $0.total != 0 }
        let total = items.map(\.total).reduce(Decimal(0), +)

        return VStack(alignment: .leading, spacing: 14) {
            Label("Spending Allocation", systemImage: "chart.pie.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if !items.isEmpty && abs(total) > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(items, id: \.tag) { item in
                            let width = geo.size.width * CGFloat(truncating: NSDecimalNumber(decimal: abs(item.total) / abs(total)))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorForTag(item.tag, snap: snap))
                                .frame(width: max(width, 4))
                        }
                    }
                }
                .frame(height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                let columns = [GridItem(.adaptive(minimum: 140))]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(items, id: \.tag) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(colorForTag(item.tag, snap: snap))
                                .frame(width: 8, height: 8)
                            Text(item.tag)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%%", abs(total) > 0 ? NSDecimalNumber(decimal: abs(item.total) / abs(total) * 100).doubleValue : 0))
                                .font(.caption)
                                .monospacedDigit()
                                .fontWeight(.medium)
                        }
                    }
                }
            } else {
                Text("No spending recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func categoryBreakdownCard(_ snap: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Categories", systemImage: "tag.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if snap.tagTotals.isEmpty {
                ContentUnavailableView("No entries", systemImage: "tray", description: Text("Add entries to see categories"))
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(snap.tagTotals, id: \.tag) { item in
                    categoryRow(item, snap: snap)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func categoryRow(_ item: (tag: String, total: Decimal), snap: Snapshot) -> some View {
        let pct = abs(snap.totalExpenses) > 0 ? CGFloat(truncating: NSDecimalNumber(decimal: abs(item.total) / abs(snap.totalExpenses))) : CGFloat(0)
        let count = snap.tagEntryCounts[item.tag, default: 0]
        let isLargest = snap.largestTag == item.tag

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Circle()
                    .fill(colorForTag(item.tag, snap: snap))
                    .frame(width: 12, height: 12)

                Text(item.tag)
                    .fontWeight(isLargest ? .semibold : .regular)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(count) \(count == 1 ? "entry" : "entries")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(String(format: "%.1f%%", pct * 100))
                    .font(.caption)
                    .monospacedDigit()
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text(MoneyHelper.format(item.total))
                    .monospacedDigit()
                    .fontWeight(isLargest ? .bold : .medium)
                    .foregroundStyle(item.total < 0 ? Color.red : Color.primary)
                    .frame(minWidth: 80, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .quaternaryLabelColor))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForTag(item.tag, snap: snap).opacity(isLargest ? 0.8 : 0.5))
                        .frame(width: geo.size.width * min(1, pct))
                }
            }
            .frame(height: isLargest ? 8 : 6)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isLargest ? colorForTag(item.tag, snap: snap).opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func metricRow(_ label: String, value: Decimal, icon: String, color: Color, accent: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(MoneyHelper.format(value))
                .monospacedDigit()
                .fontWeight(accent ? .bold : .medium)
                .foregroundStyle(accent ? color : (value < 0 ? Color.red : Color.primary))
        }
        .font(.body)
    }
}

struct MacLinearProgressBar: View {
    let value: Decimal
    let total: Decimal
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: .quaternaryLabelColor))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: total > 0 ? geo.size.width * min(1, CGFloat(truncating: NSDecimalNumber(decimal: value / total))) : 0, height: 8)
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    MacCategoryBreakdownView(month: 5, year: 2026)
        .modelContainer(BudgetingContainer.makePreviewContainer())
        .frame(width: 500, height: 400)
}

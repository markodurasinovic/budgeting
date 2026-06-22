import SwiftUI
import SwiftData
import BudgetingKit

/// The "Categories" analytics view: a big total card, a budget overview, a
/// savings card with a progress bar, a spending-allocation bar, and a
/// per-category breakdown with bars and percentages — all for the selected month.
struct MacCategoryBreakdownView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.item)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    let month: Int
    let year: Int

    private var tagTotals: [(tag: String, total: Decimal)] {
        BudgetStore.totalsByTagForMonth(entries, month: month, year: year)
    }

    private var totalExpenses: Decimal {
        tagTotals.reduce(Decimal(0)) { $0 + $1.total }
    }

    private var currentBudget: MonthlyBudget {
        BudgetStore.budgetForMonth(month, year: year, context: modelContext)
    }

    private var remainder: Decimal {
        let expenses = BudgetStore.totalForMonth(entries, month: month, year: year)
        return BudgetStore.remainder(
            income: currentBudget.income, expenses: expenses,
            bills: currentBudget.bills, savings: currentBudget.savings,
            investment: currentBudget.investment
        )
    }

    private var savingsRateValue: Decimal? {
        BudgetStore.savingsRate(
            savings: currentBudget.savings, investment: currentBudget.investment,
            income: currentBudget.income, remainder: remainder
        )
    }

    private var tagEntryCounts: [String: Int] {
        let monthEntries = BudgetStore.entriesForMonth(entries, month: month, year: year)
        var counts: [String: Int] = [:]
        for entry in monthEntries {
            counts[entry.tag, default: 0] += 1
        }
        return counts
    }

    private func colorForTag(_ tagName: String) -> Color {
        Color.hex(tagName, from: BudgetStore.tagColorHex(tags, for: tagName))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                totalCard

                HStack(spacing: 16) {
                    budgetOverviewCard
                    savingsCard
                }

                allocationCard

                categoryBreakdownCard
            }
            .padding(20)
        }
        .navigationTitle("Categories")
    }

    private var totalCard: some View {
        VStack(spacing: 12) {
            Text(DateFormatting.monthYear(month: month, year: year))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(MoneyHelper.format(totalExpenses))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(totalExpenses < 0 ? Color.red : Color.primary)

            HStack(spacing: 16) {
                Label("\(tagTotals.count) \(tagTotals.count == 1 ? "category" : "categories")", systemImage: "tag.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label("\(tagEntryCounts.values.reduce(0, +)) entries", systemImage: "list.bullet")
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

    private var budgetOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Budget", systemImage: "target")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            metricRow("Income", value: currentBudget.income, icon: "banknote.fill", color: .green)
            metricRow("Bills", value: currentBudget.bills, icon: "doc.text.fill", color: .orange)
            metricRow("Savings", value: currentBudget.savings, icon: "leaf.fill", color: .blue)
            metricRow("Investment", value: currentBudget.investment, icon: "chart.line.uptrend.xyaxis", color: .purple)

            Divider()

            metricRow("Remainder", value: remainder,
                      icon: remainder >= 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                      color: remainder >= 0 ? .green : .red, accent: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var savingsCard: some View {
        let savingsTotal = currentBudget.savings + currentBudget.investment + remainder
        let savingsPct = savingsRateValue.map { ($0 * 100).cgFloatValue }

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

            metricRow("Savings", value: currentBudget.savings, icon: "leaf.fill", color: .blue)
            metricRow("Investment", value: currentBudget.investment, icon: "chart.line.uptrend.xyaxis", color: .purple)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var allocationCard: some View {
        let items = tagTotals.filter { $0.total != 0 }
        let total = items.map(\.total).reduce(Decimal(0), +)

        return VStack(alignment: .leading, spacing: 14) {
            Label("Spending Allocation", systemImage: "chart.pie.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if !items.isEmpty, abs(total) > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(items, id: \.tag) { item in
                            let width = geo.size.width * (abs(item.total) / abs(total)).cgFloatValue
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorForTag(item.tag))
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
                                .fill(colorForTag(item.tag))
                                .frame(width: 8, height: 8)
                            Text(item.tag)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%%",
                                        abs(total) > 0 ? (abs(item.total) / abs(total) * 100).doubleValue : 0))
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

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Categories", systemImage: "tag.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if tagTotals.isEmpty {
                ContentUnavailableView("No entries", systemImage: "tray", description: Text("Add entries to see categories"))
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(tagTotals, id: \.tag) { categoryRow($0) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func categoryRow(_ item: (tag: String, total: Decimal)) -> some View {
        let pct: CGFloat = abs(totalExpenses) > 0 ? (abs(item.total) / abs(totalExpenses)).cgFloatValue : 0
        let count = tagEntryCounts[item.tag, default: 0]
        let isLargest = tagTotals.first.map { item.tag == $0.tag && item.total == $0.total } ?? false

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Circle()
                    .fill(colorForTag(item.tag))
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
                        .fill(colorForTag(item.tag).opacity(isLargest ? 0.8 : 0.5))
                        .frame(width: geo.size.width * min(1, pct))
                }
            }
            .frame(height: isLargest ? 8 : 6)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isLargest ? colorForTag(item.tag).opacity(0.06) : Color.clear)
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

#Preview {
    MacCategoryBreakdownView(month: 5, year: 2026)
        .modelContainer(BudgetingContainer.makePreviewContainer())
        .frame(width: 500, height: 400)
}

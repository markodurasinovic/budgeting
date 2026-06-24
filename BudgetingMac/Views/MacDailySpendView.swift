import SwiftUI
import SwiftData
import BudgetingKit

struct MacDailySpendView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.item)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\MonthlyBudget.year), SortDescriptor(\MonthlyBudget.month)])
    private var budgets: [MonthlyBudget]

    let month: Int
    let year: Int

    private var dailyTotals: [(day: Int, total: Decimal)] {
        BudgetStore.totalsByDayForMonth(entries, month: month, year: year)
    }

    private var maxDailyTotal: Decimal {
        dailyTotals.map(\.total).map(abs).max() ?? Decimal(0)
    }

    private var totalSpend: Decimal {
        dailyTotals.reduce(Decimal(0)) { $0 + $1.total }
    }

    private var avgDailySpend: Decimal {
        BudgetStore.averageDailySpend(entries, month: month, year: year)
    }

    private var estimatedTotal: Decimal {
        BudgetStore.estimatedMonthlySpend(entries, month: month, year: year)
    }

    private var daysElapsed: Int {
        BudgetStore.daysElapsedInMonth(month: month, year: year)
    }

    private var totalDays: Int {
        BudgetStore.daysInMonth(month: month, year: year)
    }

    private var currentBudget: MonthlyBudget {
        BudgetStore.budgetForMonth(month, year: year, context: modelContext)
    }

    private var remainder: Decimal {
        let expenses = BudgetStore.totalForMonth(entries, month: month, year: year)
        return BudgetStore.remainder(income: currentBudget.income, expenses: expenses, bills: currentBudget.bills, savings: currentBudget.savings, investment: currentBudget.investment)
    }

    private var daysRemaining: Int {
        BudgetStore.daysRemainingInMonth(month: month, year: year)
    }

    private var biggestDay: (day: Int, total: Decimal)? {
        let pastDays = dailyTotals.filter { $0.day <= daysElapsed && $0.total != 0 }
        return pastDays.max(by: { abs($0.total) < abs($1.total) })
    }

    private func spendColor(for amount: Decimal) -> Color {
        let absSpend = abs(amount)
        if absSpend >= 35 { return .red }
        if absSpend >= 25 { return .yellow }
        return .green
    }

    private func barColor(for item: (day: Int, total: Decimal)) -> Color {
        if item.day > daysElapsed || item.total == 0 {
            return Color.gray.opacity(0.15)
        }
        return spendColor(for: item.total)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                totalSpendCard

                HStack(spacing: 16) {
                    statsCard
                    budgetTrackCard
                }

                spotlightCard

                dailyBreakdownCard
            }
            .padding(20)
        }
        .navigationTitle("Daily Spend")
    }

    private var totalSpendCard: some View {
        VStack(spacing: 12) {
            Text(monthName(month, year))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(MoneyHelper.format(totalSpend))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(totalSpend < 0 ? .red : .primary)

            HStack(spacing: 24) {
                Label("\(daysElapsed) of \(totalDays) days", systemImage: "calendar")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label("\(daysRemaining) remaining", systemImage: "hourglass")
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

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Overview", systemImage: "chart.bar.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            statRow("Avg per day", value: MoneyHelper.format(avgDailySpend), icon: "divide.circle.fill", color: spendColor(for: avgDailySpend))
            statRow("Estimated total", value: MoneyHelper.format(estimatedTotal), icon: "arrow.forward.circle.fill", color: estimatedTotal < 0 ? .red : .orange)

            if let big = biggestDay {
                statRow("Biggest day", value: "Day \(big.day) — \(MoneyHelper.format(big.total))", icon: "flame.fill", color: .red)
            }

            let zeroDays = dailyTotals.filter { $0.day <= daysElapsed && $0.total == 0 }.count
            statRow("Zero-spend days", value: "\(zeroDays)", icon: "leaf.fill", color: .green)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var budgetTrackCard: some View {
        let spent = abs(BudgetStore.totalForMonth(entries, month: month, year: year))
        let budget = currentBudget.income - currentBudget.bills - currentBudget.savings - currentBudget.investment
        let budgetUsedPct = budget > 0 ? CGFloat(truncating: NSDecimalNumber(decimal: spent / budget * 100)) : CGFloat(0)
        let dailyBudget = daysRemaining > 0 ? remainder / Decimal(daysRemaining) : Decimal(0)

        return VStack(alignment: .leading, spacing: 14) {
            Label("Budget", systemImage: "target")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            budgetMetric("Remainder", value: remainder, color: remainder >= 0 ? .green : .red)
            budgetMetric("Daily budget", value: dailyBudget, color: dailyBudget >= 0 ? .green : .red)

            if budget > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Budget used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f%%", budgetUsedPct))
                            .font(.caption)
                            .monospacedDigit()
                            .fontWeight(.medium)
                            .foregroundStyle(budgetUsedPct > 100 ? .red : .primary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
.fill(Color(nsColor: .quaternaryLabelColor))
                                .frame(height: 10)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(budgetUsedPct > 100 ? Color.red : Color.accentColor)
                                .frame(width: geo.size.width * min(1, budgetUsedPct / 100), height: 10)
                        }
                    }
                    .frame(height: 10)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var spotlightCard: some View {
        let pastDays = dailyTotals.filter { $0.day <= daysElapsed }
        let sortedByAmount = pastDays.filter { $0.total != 0 }.sorted { abs($0.total) > abs($1.total) }
        let top3 = Array(sortedByAmount.prefix(3))

        return VStack(alignment: .leading, spacing: 14) {
            Label("Top Spending Days", systemImage: "flame.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if top3.isEmpty {
                Text("No spending yet this month")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(top3, id: \.day) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(spendColor(for: item.total).opacity(0.2))
                            .overlay(
                                Text("\(item.day)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(spendColor(for: item.total))
                            )
                            .frame(width: 28, height: 28)

                        Text(dayName(item.day))
                            .font(.body)
                        Spacer()
                        Text(MoneyHelper.format(item.total))
                            .font(.body)
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .foregroundStyle(item.total < 0 ? Color.red : Color.primary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var dailyBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Daily Breakdown", systemImage: "calendar.day.timeline.leading")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(dailyTotals, id: \.day) { item in
                dailyRow(item)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func dailyRow(_ item: (day: Int, total: Decimal)) -> some View {
        let isFuture = item.day > daysElapsed
        let isZero = item.total == 0
        let isToday = item.day == daysElapsed
        let color = barColor(for: item)

        return HStack(spacing: 10) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 28, height: 28)
                }
                Text("\(item.day)")
                    .font(isToday ? .body : .caption)
                    .monospacedDigit()
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isFuture ? Color.secondary : (isToday ? Color.white : Color.primary))
            }
            .frame(width: 28)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .quaternaryLabelColor))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: isZero || isFuture ? 0 : geo.size.width * min(1, CGFloat(truncating: NSDecimalNumber(decimal: abs(item.total) / max(maxDailyTotal, Decimal(1))))))
                }
            }
            .frame(height: isToday ? 8 : 6)

            Spacer()

            Text(MoneyHelper.format(item.total))
                .font(isToday ? .body : .caption)
                .monospacedDigit()
                .fontWeight(isToday ? .bold : (isZero || isFuture ? .regular : .medium))
                .foregroundStyle(isFuture ? Color.secondary : (item.total < 0 ? Color.red : (isZero ? Color.secondary : Color.primary)))
                .frame(minWidth: 72, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(isToday ? Color.accentColor.opacity(0.08) : (isFuture ? Color.clear : (isZero ? Color.clear : spendColor(for: item.total).opacity(0.06))))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func statRow(_ label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .fontWeight(.medium)
        }
        .font(.body)
    }

    private func budgetMetric(_ label: String, value: Decimal, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: value >= 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(MoneyHelper.format(value))
                .monospacedDigit()
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .font(.body)
    }

    private func dayName(_ day: Int) -> String {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = Calendar.current.date(from: components) else { return "Day \(day)" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE d"
        return fmt.string(from: date)
    }

    private func monthName(_ month: Int, _ year: Int) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "\(month)/\(year)" }
        return fmt.string(from: date)
    }
}

#Preview {
    MacDailySpendView(month: 5, year: 2026)
        .modelContainer(BudgetingContainer.makePreviewContainer())
        .frame(width: 500, height: 600)
}
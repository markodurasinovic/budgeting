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

    struct Snapshot {
        let dailyTotals: [(day: Int, total: Decimal)]
        let maxDailyTotal: Decimal
        let totalSpend: Decimal
        let avgDailySpend: Decimal
        let estimatedTotal: Decimal
        let daysElapsed: Int
        let daysRemaining: Int
        let totalDays: Int
        let currentBudget: MonthlyBudget
        let remainder: Decimal
        let biggestDay: (day: Int, total: Decimal)?
        let topSpendingDays: [(day: Int, total: Decimal)]
        let zeroDays: Int
    }

    private var snapshot: Snapshot {
        let cal = Calendar.current
        let daysInMonth = BudgetStore.daysInMonth(month: month, year: year)
        let now = Date()
        let currentMonth = cal.component(.month, from: now)
        let currentYear = cal.component(.year, from: now)
        let isCurrentMonth = month == currentMonth && year == currentYear

        var totalsByDay: [Int: Decimal] = [:]
        for entry in entries {
            let comps = cal.dateComponents([.month, .year, .day], from: entry.date)
            if comps.month == month && comps.year == year, let day = comps.day {
                totalsByDay[day, default: Decimal(0)] += entry.amount
            }
        }
        let dailyTotals = (1...daysInMonth).map { day in
            (day: day, total: totalsByDay[day] ?? Decimal(0))
        }

        let maxDailyTotal = dailyTotals.map(\.total).map(abs).max() ?? Decimal(0)
        let totalSpend = dailyTotals.reduce(Decimal(0)) { $0 + $1.total }

        let daysElapsed: Int
        if isCurrentMonth {
            daysElapsed = cal.component(.day, from: now)
        } else {
            daysElapsed = daysInMonth
        }
        let daysRemaining: Int
        if isCurrentMonth {
            daysRemaining = max(daysInMonth - daysElapsed + 1, 0)
        } else if year < currentYear || (year == currentYear && month < currentMonth) {
            daysRemaining = 0
        } else {
            daysRemaining = daysInMonth
        }

        let avgDailySpend = daysElapsed > 0 ? totalSpend / Decimal(daysElapsed) : Decimal(0)
        let estimatedTotal = avgDailySpend * Decimal(daysInMonth)

        let currentBudget = BudgetStore.budgetForMonth(month, year: year, context: modelContext)
        let remainder = BudgetStore.remainder(income: currentBudget.income, expenses: totalSpend, bills: currentBudget.bills, savings: currentBudget.savings, investment: currentBudget.investment)

        let pastDays = dailyTotals.filter { $0.day <= daysElapsed && $0.total != 0 }
        let biggestDay = pastDays.max(by: { abs($0.total) < abs($1.total) })
        let sortedByAmount = pastDays.sorted { abs($0.total) > abs($1.total) }
        let topSpendingDays = Array(sortedByAmount.prefix(3))
        let zeroDays = dailyTotals.filter { $0.day <= daysElapsed && $0.total == 0 }.count

        return Snapshot(
            dailyTotals: dailyTotals,
            maxDailyTotal: maxDailyTotal,
            totalSpend: totalSpend,
            avgDailySpend: avgDailySpend,
            estimatedTotal: estimatedTotal,
            daysElapsed: daysElapsed,
            daysRemaining: daysRemaining,
            totalDays: daysInMonth,
            currentBudget: currentBudget,
            remainder: remainder,
            biggestDay: biggestDay,
            topSpendingDays: topSpendingDays,
            zeroDays: zeroDays
        )
    }

    private func spendColor(for amount: Decimal) -> Color {
        let absSpend = abs(amount)
        if absSpend >= 35 { return .red }
        if absSpend >= 25 { return .yellow }
        return .green
    }

    private func barColor(for item: (day: Int, total: Decimal), snap: Snapshot) -> Color {
        if item.day > snap.daysElapsed || item.total == 0 {
            return Color.gray.opacity(0.15)
        }
        return spendColor(for: item.total)
    }

    var body: some View {
        let snap = snapshot
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                totalSpendCard(snap)
                HStack(spacing: 16) {
                    statsCard(snap)
                    budgetTrackCard(snap)
                }
                spotlightCard(snap)
                dailyBreakdownCard(snap)
            }
            .padding(20)
        }
        .navigationTitle("Daily Spend")
    }

    private func totalSpendCard(_ snap: Snapshot) -> some View {
        VStack(spacing: 12) {
            Text(Formatters.monthYearString(month: month, year: year))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(MoneyHelper.format(snap.totalSpend))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(snap.totalSpend < 0 ? .red : .primary)

            HStack(spacing: 24) {
                Label("\(snap.daysElapsed) of \(snap.totalDays) days", systemImage: "calendar")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label("\(snap.daysRemaining) remaining", systemImage: "hourglass")
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

    private func statsCard(_ snap: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Overview", systemImage: "chart.bar.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            statRow("Avg per day", value: MoneyHelper.format(snap.avgDailySpend), icon: "divide.circle.fill", color: spendColor(for: snap.avgDailySpend))
            statRow("Estimated total", value: MoneyHelper.format(snap.estimatedTotal), icon: "arrow.forward.circle.fill", color: snap.estimatedTotal < 0 ? .red : .orange)

            if let big = snap.biggestDay {
                statRow("Biggest day", value: "Day \(big.day) — \(MoneyHelper.format(big.total))", icon: "flame.fill", color: .red)
            }

            statRow("Zero-spend days", value: "\(snap.zeroDays)", icon: "leaf.fill", color: .green)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func budgetTrackCard(_ snap: Snapshot) -> some View {
        let spent = abs(snap.totalSpend)
        let budget = snap.currentBudget.income - snap.currentBudget.bills - snap.currentBudget.savings - snap.currentBudget.investment
        let budgetUsedPct = budget > 0 ? CGFloat(truncating: NSDecimalNumber(decimal: spent / budget * 100)) : CGFloat(0)
        let dailyBudget = snap.daysRemaining > 0 ? snap.remainder / Decimal(snap.daysRemaining) : Decimal(0)

        return VStack(alignment: .leading, spacing: 14) {
            Label("Budget", systemImage: "target")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            budgetMetric("Remainder", value: snap.remainder, color: snap.remainder >= 0 ? .green : .red)
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

    private func spotlightCard(_ snap: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Top Spending Days", systemImage: "flame.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if snap.topSpendingDays.isEmpty {
                Text("No spending yet this month")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(snap.topSpendingDays, id: \.day) { item in
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

                        Text(Formatters.shortDayString(day: item.day, month: month, year: year))
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

    private func dailyBreakdownCard(_ snap: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Daily Breakdown", systemImage: "calendar.day.timeline.leading")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(snap.dailyTotals, id: \.day) { item in
                dailyRow(item, snap: snap)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func dailyRow(_ item: (day: Int, total: Decimal), snap: Snapshot) -> some View {
        let isFuture = item.day > snap.daysElapsed
        let isZero = item.total == 0
        let isToday = item.day == snap.daysElapsed
        let color = barColor(for: item, snap: snap)

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
                        .frame(width: isZero || isFuture ? 0 : geo.size.width * min(1, CGFloat(truncating: NSDecimalNumber(decimal: abs(item.total) / max(snap.maxDailyTotal, Decimal(1))))))
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
}

#Preview {
    MacDailySpendView(month: 5, year: 2026)
        .modelContainer(BudgetingContainer.makePreviewContainer())
        .frame(width: 500, height: 600)
}
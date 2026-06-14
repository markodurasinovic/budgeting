import SwiftUI
import SwiftData
import BudgetingKit

struct MacDailySpendView: View {
    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.item)])
    private var entries: [Entry]

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
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Spend")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Days elapsed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(daysElapsed) of \(totalDays)")
                        .font(.body)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total spent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(MoneyHelper.format(totalSpend))
                        .font(.body)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Avg per day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(spendColor(for: avgDailySpend))
                            .frame(width: 10, height: 10)
                        Text(MoneyHelper.format(avgDailySpend))
                            .font(.body)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(MoneyHelper.format(estimatedTotal))
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal)

            Divider()
                .padding(.horizontal)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(dailyTotals, id: \.day) { item in
                        let isFuture = item.day > daysElapsed
                        let isZero = item.total == 0
                        let amountColor: Color = {
                            if isFuture { return .secondary }
                            if isZero { return .secondary }
                            if item.total < 0 { return .red }
                            return .primary
                        }()
                        let isBold = !isFuture && !isZero
                        let rowBg: Color = {
                            if isFuture || isZero { return Color.clear }
                            return spendColor(for: item.total).opacity(0.08)
                        }()
                        HStack(spacing: 10) {
                            Text("\(item.day)")
                                .font(.caption)
                                .monospacedDigit()
                                .frame(width: 24, alignment: .trailing)
                                .foregroundStyle(isFuture ? .secondary : .primary)

                            MacLinearProgressBar(
                                value: abs(item.total),
                                total: max(maxDailyTotal, Decimal(1)),
                                color: barColor(for: item)
                            )
                            .frame(height: 20)

                            Text(MoneyHelper.format(item.total))
                                .font(.body)
                                .monospacedDigit()
                                .frame(minWidth: 80, alignment: .trailing)
                                .foregroundStyle(amountColor)
                                .fontWeight(isBold ? .medium : .regular)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(rowBg)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }
}

#Preview {
    MacDailySpendView(month: 5, year: 2026)
        .modelContainer(BudgetingContainer.makePreviewContainer())
        .frame(width: 500, height: 600)
}
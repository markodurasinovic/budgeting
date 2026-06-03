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
        dailyTotals.map(\.total).max() ?? Decimal(0)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Spend")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            HStack(spacing: 24) {
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
                    Text(MoneyHelper.format(avgDailySpend))
                        .font(.body)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(MoneyHelper.format(estimatedTotal))
                        .font(.body)
                        .foregroundStyle(estimatedTotal > totalSpend ? .orange : .green)
                }
            }
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(dailyTotals, id: \.day) { item in
                        HStack(spacing: 8) {
                            Text("\(item.day)")
                                .font(.caption)
                                .monospacedDigit()
                                .frame(width: 24, alignment: .trailing)
                                .foregroundStyle(item.day <= daysElapsed ? .primary : .secondary)

                            MacLinearProgressBar(
                                value: abs(item.total),
                                total: max(maxDailyTotal, Decimal(1)),
                                color: barColor(for: item)
                            )

                            Text(MoneyHelper.format(item.total))
                                .font(.caption)
                                .monospacedDigit()
                                .frame(minWidth: 70, alignment: .trailing)
                                .foregroundStyle(item.total < 0 ? .red : item.total == 0 ? .secondary : .primary)
                        }
                        .padding(.vertical, 1)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }

    private func barColor(for item: (day: Int, total: Decimal)) -> Color {
        if item.day > daysElapsed || item.total == 0 {
            return Color.gray.opacity(0.2)
        }
        let absSpend = abs(item.total)
        if absSpend >= 35 {
            return .red
        }
        if absSpend >= 25 {
            return .yellow
        }
        return .green
    }
}

#Preview {
    MacDailySpendView(month: 5, year: 2026)
        .modelContainer(BudgetingContainer.makePreviewContainer())
        .frame(width: 500, height: 600)
}
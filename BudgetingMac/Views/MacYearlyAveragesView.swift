import SwiftUI
import SwiftData
import BudgetingKit

struct MacYearlyAveragesView: View {
    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.item)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    @Query private var budgets: [MonthlyBudget]

    let year: Int
    let onShiftYear: (Int) -> Void

    struct Snapshot {
        let completedTotal: Decimal
        let completedMonths: Int
        let averageMonthly: Decimal
        let monthlyTotals: [(month: Int, total: Decimal)]
        let maxMonthlyTotal: Decimal
        let currentMonth: Int?
        let bestMonth: (month: Int, total: Decimal)?
        let worstMonth: (month: Int, total: Decimal)?
        let tagAverages: [(tag: String, average: Decimal, total: Decimal)]
        let tagEntryCounts: [String: Int]
        let totalEntryCount: Int
        let largestTag: String?
        let tagColors: [String: Color]
        let averageIncome: Decimal
        let averageBills: Decimal
        let averageSpend: Decimal
        let averageSavings: Decimal
        let averageInvestment: Decimal
        let averageRemainder: Decimal
        let averageSaved: Decimal
        let savingsTotal: Decimal
        let savingsRate: Decimal?
    }

    private var snapshot: Snapshot {
        let cal = Calendar.current
        let completedMonths = BudgetStore.completedMonthsInYear(year: year)
        let divisor = completedMonths > 0 ? Decimal(completedMonths) : nil
        func average(_ total: Decimal) -> Decimal {
            divisor.map { total / $0 } ?? Decimal(0)
        }

        let total = BudgetStore.totalForCompletedMonths(entries, year: year)
        let averageMonthly = average(total)
        let monthlyTotals = BudgetStore.totalsByMonthForYear(entries, year: year)
        let maxMonthlyTotal = monthlyTotals.map(\.total).map(abs).max() ?? Decimal(0)

        let completedTotals = monthlyTotals.filter { $0.month <= completedMonths && $0.total != 0 }
        let bestMonth = completedTotals.max { $0.total < $1.total }
        let worstMonth = completedTotals.min { $0.total < $1.total }

        let yearEntries = BudgetStore.entriesForCompletedMonths(entries, year: year)
        var tagEntryCounts: [String: Int] = [:]
        for entry in yearEntries {
            tagEntryCounts[entry.tag, default: 0] += 1
        }
        let tagAverages = BudgetStore.averageMonthlyByTag(entries, year: year)
        let largestTag = tagAverages.first?.tag

        var tagColors: [String: Color] = [:]
        for tag in tags {
            tagColors[tag.name] = Color.hex(tag.name, from: BudgetStore.tagColorHex(tags, for: tag.name))
        }

        let yearBudgets = budgets.filter { $0.year == year && $0.month <= completedMonths }
        let totalIncome = yearBudgets.reduce(Decimal(0)) { $0 + $1.income }
        let totalBills = yearBudgets.reduce(Decimal(0)) { $0 + $1.bills }
        let totalSavings = yearBudgets.reduce(Decimal(0)) { $0 + $1.savings }
        let totalInvestment = yearBudgets.reduce(Decimal(0)) { $0 + $1.investment }
        let remainder = BudgetStore.remainder(income: totalIncome, expenses: total, bills: totalBills, savings: totalSavings, investment: totalInvestment)
        let savingsRate = BudgetStore.savingsRate(savings: totalSavings, investment: totalInvestment, income: totalIncome, remainder: remainder)
        let savingsTotal = totalSavings + totalInvestment + remainder

        let currentMonth: Int?
        if year == cal.component(.year, from: Date()) {
            currentMonth = cal.component(.month, from: Date())
        } else {
            currentMonth = nil
        }

        return Snapshot(
            completedTotal: total,
            completedMonths: completedMonths,
            averageMonthly: averageMonthly,
            monthlyTotals: monthlyTotals,
            maxMonthlyTotal: maxMonthlyTotal,
            currentMonth: currentMonth,
            bestMonth: bestMonth,
            worstMonth: worstMonth,
            tagAverages: tagAverages,
            tagEntryCounts: tagEntryCounts,
            totalEntryCount: yearEntries.count,
            largestTag: largestTag,
            tagColors: tagColors,
            averageIncome: average(totalIncome),
            averageBills: average(totalBills),
            averageSpend: averageMonthly,
            averageSavings: average(totalSavings),
            averageInvestment: average(totalInvestment),
            averageRemainder: average(remainder),
            averageSaved: average(savingsTotal),
            savingsTotal: savingsTotal,
            savingsRate: savingsRate
        )
    }

    private func colorForTag(_ tagName: String, snap: Snapshot) -> Color {
        snap.tagColors[tagName] ?? Color.hex(tagName, from: nil)
    }

    var body: some View {
        let snap = snapshot
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                yearCard(snap)
                HStack(spacing: 16) {
                    averagesCard(snap)
                    savingsCard(snap)
                }
                trendCard(snap)
                categoryAveragesCard(snap)
            }
            .padding(20)
        }
        .navigationTitle("Yearly Averages")
    }

    private func yearCard(_ snap: Snapshot) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button {
                    onShiftYear(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Text(String(year))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    onShiftYear(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }

            Text(MoneyHelper.format(snap.completedTotal))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(snap.completedTotal < 0 ? Color.red : Color.primary)

            HStack(spacing: 16) {
                Label("Avg \(MoneyHelper.format(snap.averageMonthly)) / month", systemImage: "divide.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label("\(snap.completedMonths) completed \(snap.completedMonths == 1 ? "month" : "months")", systemImage: "calendar")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label("\(snap.totalEntryCount) entries", systemImage: "list.bullet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if snap.currentMonth != nil {
                Text("Current month excluded until it completes")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if snap.bestMonth != nil || snap.worstMonth != nil {
                Divider()

                HStack(spacing: 16) {
                    if let best = snap.bestMonth {
                        monthStat("Highest month", month: best.month, total: best.total, icon: "trophy.fill", color: .green)
                    }
                    if let worst = snap.worstMonth {
                        monthStat("Lowest month", month: worst.month, total: worst.total, icon: "flame.fill", color: .red)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func monthStat(_ title: String, month: Int, total: Decimal, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formatters.shortMonthString(month: month))
                    .font(.body)
                    .fontWeight(.semibold)
            }
            Spacer()
            Text(MoneyHelper.format(total))
                .monospacedDigit()
                .fontWeight(.medium)
                .foregroundStyle(total < 0 ? Color.red : Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func averagesCard(_ snap: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Monthly Averages", systemImage: "target")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            metricRow("Avg income", value: snap.averageIncome, icon: "banknote.fill", color: .green)
            metricRow("Avg bills", value: snap.averageBills, icon: "doc.text.fill", color: .orange)
            metricRow("Avg spend", value: snap.averageSpend, icon: "chart.bar.fill", color: .red)
            metricRow("Avg savings", value: snap.averageSavings, icon: "leaf.fill", color: .blue)
            metricRow("Avg investment", value: snap.averageInvestment, icon: "chart.line.uptrend.xyaxis", color: .purple)

            Divider()

            metricRow("Avg remainder", value: snap.averageRemainder, icon: snap.averageRemainder >= 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill", color: snap.averageRemainder >= 0 ? .green : .red, accent: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func savingsCard(_ snap: Snapshot) -> some View {
        let savingsPct = snap.savingsRate.map { CGFloat(truncating: NSDecimalNumber(decimal: $0 * 100)) }

        return VStack(alignment: .leading, spacing: 14) {
            Label("Savings", systemImage: "leaf.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(MoneyHelper.format(snap.averageSaved))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(snap.averageSaved >= 0 ? Color.blue : Color.red)

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

                Text("\(MoneyHelper.format(snap.savingsTotal)) saved this year")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()

            metricRow("Avg savings", value: snap.averageSavings, icon: "leaf.fill", color: .blue)
            metricRow("Avg investment", value: snap.averageInvestment, icon: "chart.line.uptrend.xyaxis", color: .purple)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func trendCard(_ snap: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Monthly Trend", systemImage: "chart.bar.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(snap.monthlyTotals, id: \.month) { item in
                monthRow(item, snap: snap)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func monthBarColor(_ item: (month: Int, total: Decimal), snap: Snapshot) -> Color {
        let isExcluded = item.month > snap.completedMonths
        guard !isExcluded, item.total != 0 else { return .gray.opacity(0.15) }
        if item.total > 0 { return .green }
        return abs(item.total) > abs(snap.averageMonthly) ? .red : .green
    }

    private func monthRow(_ item: (month: Int, total: Decimal), snap: Snapshot) -> some View {
        let isExcluded = item.month > snap.completedMonths
        let isZero = item.total == 0
        let isCurrent = snap.currentMonth == item.month
        let color = monthBarColor(item, snap: snap)

        return HStack(spacing: 10) {
            ZStack {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                        .frame(width: 40, height: 22)
                }
                Text(Formatters.shortMonthString(month: item.month))
                    .font(isCurrent ? .body : .caption)
                    .fontWeight(isCurrent ? .bold : .regular)
                    .foregroundStyle(isExcluded ? Color.secondary : (isCurrent ? Color.white : Color.primary))
            }
            .frame(width: 40)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .quaternaryLabelColor))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: isZero || isExcluded ? 0 : geo.size.width * min(1, CGFloat(truncating: NSDecimalNumber(decimal: abs(item.total) / max(snap.maxMonthlyTotal, Decimal(1))))))
                }
            }
            .frame(height: isCurrent ? 8 : 6)

            Spacer()

            Text(MoneyHelper.format(item.total))
                .font(isCurrent ? .body : .caption)
                .monospacedDigit()
                .fontWeight(isCurrent ? .bold : (isZero || isExcluded ? .regular : .medium))
                .foregroundStyle(isExcluded ? Color.secondary : (item.total < 0 ? Color.red : (isZero ? Color.secondary : Color.primary)))
                .frame(minWidth: 72, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(isCurrent ? Color.accentColor.opacity(0.08) : (isExcluded || isZero ? Color.clear : color.opacity(0.06)))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func categoryAveragesCard(_ snap: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Average per Category", systemImage: "tag.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("per month · \(snap.completedMonths) completed \(snap.completedMonths == 1 ? "month" : "months")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if snap.tagAverages.isEmpty {
                ContentUnavailableView("No entries", systemImage: "tray", description: Text("No entries in completed months"))
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(snap.tagAverages, id: \.tag) { item in
                    categoryRow(item, snap: snap)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func categoryRow(_ item: (tag: String, average: Decimal, total: Decimal), snap: Snapshot) -> some View {
        let pct = abs(snap.completedTotal) > 0 ? CGFloat(truncating: NSDecimalNumber(decimal: abs(item.total) / abs(snap.completedTotal))) : CGFloat(0)
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

                Text(MoneyHelper.format(item.average))
                    .monospacedDigit()
                    .fontWeight(isLargest ? .bold : .medium)
                    .foregroundStyle(item.average < 0 ? Color.red : Color.primary)
                    .frame(minWidth: 90, alignment: .trailing)

                Text(MoneyHelper.format(item.total))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
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

#Preview {
    MacYearlyAveragesView(year: 2026, onShiftYear: { _ in })
        .modelContainer(BudgetingContainer.makePreviewContainer())
        .frame(width: 500, height: 600)
}

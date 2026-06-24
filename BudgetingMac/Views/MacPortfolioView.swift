import SwiftUI
import SwiftData
import BudgetingKit

struct MacPortfolioView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\PortfolioSnapshot.year), SortDescriptor(\PortfolioSnapshot.month)])
    private var portfolios: [PortfolioSnapshot]

    @Query(sort: [SortDescriptor(\DebtSnapshot.year), SortDescriptor(\DebtSnapshot.month)])
    private var debts: [DebtSnapshot]

    let month: Int
    let year: Int

    @State private var editState: PortfolioEditState?

    struct Snapshot {
        let allRows: [PortfolioRow]
        let currentRow: PortfolioRow?
        let previousRow: PortfolioRow?
        let maxNetWorth: Decimal
    }

    private var snapshot: Snapshot {
        let allRows = PortfolioStore.allRows(portfolios: portfolios, debts: debts)
        let currentRow = allRows.first { $0.portfolio.month == month && $0.portfolio.year == year }
        let previousRow = allRows.first { $0.portfolio.year < year || ($0.portfolio.year == year && $0.portfolio.month < month) }
        let maxNet = allRows.map(\.netGrandWorth).map(abs).max() ?? Decimal(1)
        return Snapshot(allRows: allRows, currentRow: currentRow, previousRow: previousRow, maxNetWorth: maxNet)
    }

    var body: some View {
        let snap = snapshot
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let row = snap.currentRow {
                    netWorthCard(row: row, snap: snap)

                    HStack(spacing: 16) {
                        investmentCard(row: row, snap: snap)
                        debtsCard(row: row, snap: snap)
                    }

                    allocationCard(row: row)

                    if let notes = row.portfolio.notes.nilIfEmpty {
                        notesCard(notes: notes)
                    }

                    if !snap.allRows.isEmpty {
                        historyCard(snap)
                    }
                } else {
                    ContentUnavailableView("No data for \(Formatters.monthYearString(month: month, year: year))", systemImage: "chart.line.uptrend.xyaxis", description: Text("Tap + to add a snapshot"))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    let p = PortfolioStore.snapshotForMonth(month, year: year, context: modelContext)
                    let d = PortfolioStore.debtForMonth(month, year: year, context: modelContext)
                    editState = PortfolioEditState(portfolio: p, debt: d)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .navigationTitle("Portfolio")
        .sheet(item: $editState) { state in
            MacPortfolioEditView(portfolio: state.portfolio, debt: state.debt)
        }
    }

    private func netWorthCard(row: PortfolioRow, snap: Snapshot) -> some View {
        let delta = snap.previousRow.map { PortfolioStore.delta(current: row.netGrandWorth, previous: $0.netGrandWorth) }
        let deltaPct = snap.previousRow.map { PortfolioStore.deltaPercent(current: row.netGrandWorth, previous: $0.netGrandWorth) }
        let isPositive = delta.map { $0 >= 0 } ?? true

        return VStack(spacing: 12) {
            Text(row.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(MoneyHelper.format(row.netGrandWorth))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()

            if let d = delta {
                HStack(spacing: 8) {
                    Image(systemName: isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.caption)
                    Text(PortfolioStore.formatDelta(d))
                        .fontWeight(.semibold)
                    if let pct = deltaPct {
                        Text("(\(PortfolioStore.formatDeltaPercent(pct)))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
                .foregroundStyle(isPositive ? .green : .red)
            } else {
                Text("No previous data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func investmentCard(row: PortfolioRow, snap: Snapshot) -> some View {
        let delta = snap.previousRow.map { PortfolioStore.delta(current: row.grandTotal, previous: $0.grandTotal) }

        return VStack(alignment: .leading, spacing: 14) {
            Label("Investments", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            investmentRow("S&S ISA", value: row.portfolio.ssIsa, icon: "chart.bar.fill", color: .blue)
            investmentRow("Cash ISA", value: row.portfolio.cashIsa, icon: "banknote.fill", color: .green)
            investmentRow("LISA", value: row.portfolio.lisa, icon: "house.fill", color: .orange)
            investmentRow("Crypto", value: row.portfolio.crypto, icon: "bitcoinsign.circle.fill", color: .purple)
            investmentRow("Pension", value: row.portfolio.pension, icon: "building.columns.fill", color: .teal)

            Divider()

            totalRow("Grand Total", value: row.grandTotal, delta: delta, accent: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func debtsCard(row: PortfolioRow, snap: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Debts", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(row.debtTotal > 0 ? .red : .secondary)

            if let d = row.debt {
                debtRow("Chase", value: d.chase)
                debtRow("Amex", value: d.amex)
                debtRow("Other", value: d.other)

                Divider()

                totalRow("Debt Total", value: row.debtTotal, delta: snap.previousRow.flatMap { pr in pr.debt.map { PortfolioStore.delta(current: row.debtTotal, previous: $0.chase + $0.amex + $0.other) } }, isDebt: true)
            } else {
                ContentUnavailableView("No debts", systemImage: "checkmark.circle.fill", description: Text("Looking good!"))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func allocationCard(row: PortfolioRow) -> some View {
        let items: [(String, Decimal, Color)] = [
            ("S&S ISA", row.portfolio.ssIsa, .blue),
            ("Cash ISA", row.portfolio.cashIsa, .green),
            ("LISA", row.portfolio.lisa, .orange),
            ("Crypto", row.portfolio.crypto, .purple),
            ("Pension", row.portfolio.pension, .teal),
        ].filter { $0.1 > 0 }

        let total = items.map(\.1).reduce(Decimal(0), +)

        return VStack(alignment: .leading, spacing: 14) {
            Label("Allocation", systemImage: "chart.pie.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if total > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(items, id: \.0) { item in
                            let width = geo.size.width * CGFloat(truncating: NSDecimalNumber(decimal: item.1 / total))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.2)
                                .frame(width: max(width, 4))
                        }
                    }
                }
                .frame(height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                let columns = [GridItem(.adaptive(minimum: 140))]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(items, id: \.0) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.2)
                                .frame(width: 8, height: 8)
                            Text(item.0)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%%", NSDecimalNumber(decimal: item.1 / total * 100).doubleValue))
                                .font(.caption)
                                .monospacedDigit()
                                .fontWeight(.medium)
                        }
                    }
                }
            } else {
                Text("No investments recorded")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func notesCard(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(notes)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func historyCard(_ snap: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("History", systemImage: "clock.arrow.circlepath")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(snap.allRows) { row in
                historyRow(row, snap: snap)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func historyRow(_ row: PortfolioRow, snap: Snapshot) -> some View {
        let isCurrent = row.portfolio.month == month && row.portfolio.year == year
        let pct = CGFloat(truncating: NSDecimalNumber(decimal: abs(row.netGrandWorth) / max(snap.maxNetWorth, 1)))

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.label)
                    .font(isCurrent ? .body : .caption)
                    .fontWeight(isCurrent ? .bold : .regular)
                    .foregroundStyle(isCurrent ? .primary : .secondary)
                Spacer()
                Text(MoneyHelper.format(row.netGrandWorth))
                    .font(isCurrent ? .body : .caption)
                    .monospacedDigit()
                    .fontWeight(isCurrent ? .bold : .medium)
                    .foregroundStyle(row.netGrandWorth >= 0 ? Color.primary : Color.red)
            }

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(isCurrent ? Color.accentColor.opacity(0.6) : Color.accentColor.opacity(0.2))
                    .frame(width: geo.size.width * min(1, pct))
            }
            .frame(height: isCurrent ? 6 : 4)
        }
        .padding(.vertical, 2)
    }

    private func investmentRow(_ label: String, value: Decimal, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .foregroundStyle(value > 0 ? .primary : .secondary)
            Spacer()
            Text(MoneyHelper.format(value))
                .monospacedDigit()
                .foregroundStyle(value > 0 ? .primary : .secondary)
        }
        .font(.body)
    }

    private func debtRow(_ label: String, value: Decimal) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "creditcard.fill")
                .foregroundStyle(value > 0 ? .red : .secondary)
                .frame(width: 16)
            Text(label)
                .foregroundStyle(value > 0 ? .primary : .secondary)
            Spacer()
            Text(MoneyHelper.format(value))
                .monospacedDigit()
                .foregroundStyle(value > 0 ? .red : .secondary)
        }
        .font(.body)
    }

    private func totalRow(_ label: String, value: Decimal, delta: Decimal?, accent: Bool = false, isDebt: Bool = false) -> some View {
        HStack {
            Text(label)
                .fontWeight(accent ? .bold : .semibold)
                .font(accent ? .title3 : .body)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyHelper.format(value))
                    .fontWeight(accent ? .bold : .semibold)
                    .font(accent ? .title3 : .body)
                    .monospacedDigit()
                    .foregroundStyle(isDebt && value > 0 ? .red : .primary)
                if let d = delta {
                    let isPositive = d >= 0
                    Text(PortfolioStore.formatDelta(d))
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(isDebt ? (isPositive ? .red : .green) : (isPositive ? .green : .red))
                }
            }
        }
    }
}

#Preview {
    MacPortfolioView(month: 6, year: 2026)
        .modelContainer(BudgetingContainer.makePreviewContainer())
        .frame(width: 600, height: 500)
}
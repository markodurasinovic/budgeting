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

    private var currentRow: PortfolioRow? {
        let allRows = PortfolioStore.allRows(portfolios: portfolios, debts: debts)
        return allRows.first { $0.portfolio.month == month && $0.portfolio.year == year }
    }

    private var previousRow: PortfolioRow? {
        let allRows = PortfolioStore.allRows(portfolios: portfolios, debts: debts)
        return allRows.first { $0.portfolio.year < year || ($0.portfolio.year == year && $0.portfolio.month < month) }
    }

    private var allRows: [PortfolioRow] {
        PortfolioStore.allRows(portfolios: portfolios, debts: debts)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let row = currentRow {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(row.label)
                            .font(.headline)

                        portfolioRow("S&S ISA", value: row.portfolio.ssIsa)
                        portfolioRow("Cash ISA", value: row.portfolio.cashIsa)
                        portfolioRow("LISA", value: row.portfolio.lisa)
                        portfolioRow("Crypto", value: row.portfolio.crypto)
                        Divider()
                        totalRow("Total (excl. pension)", value: row.totalExPension, delta: previousRow.map { PortfolioStore.delta(current: row.totalExPension, previous: $0.totalExPension) })
                        portfolioRow("Pension", value: row.portfolio.pension)
                        totalRow("Grand Total", value: row.grandTotal, delta: previousRow.map { PortfolioStore.delta(current: row.grandTotal, previous: $0.grandTotal) })
                        if let notes = row.portfolio.notes.nilIfEmpty {
                            Text("Notes: \(notes)").font(.caption).foregroundStyle(.secondary)
                        }
                        if let d = row.debt {
                            Divider()
                            Text("Debts").font(.subheadline).fontWeight(.semibold)
                            portfolioRow("Chase", value: d.chase)
                            portfolioRow("Amex", value: d.amex)
                            portfolioRow("Other", value: d.other)
                            let dt = row.debtTotal
                            totalRow("Debt Total", value: dt, delta: previousRow.flatMap { pr in pr.debt.map { PortfolioStore.delta(current: dt, previous: $0.chase + $0.amex + $0.other) } })
                            Divider()
                            totalRow("Net Worth", value: row.netGrandWorth, delta: previousRow.map { PortfolioStore.delta(current: row.netGrandWorth, previous: $0.netGrandWorth) })
                        }
                    }
                    .padding()
                    .background(.bar)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if !allRows.isEmpty {
                        Text("History")
                            .font(.title3)
                            .padding(.horizontal)

                        ForEach(allRows) { row in
                            HStack {
                                Text(row.label)
                                    .font(.caption)
                                Spacer()
                                Text(MoneyHelper.format(row.netGrandWorth))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    ContentUnavailableView("No data for \(monthName(month, year))", systemImage: "chart.line.uptrend.xyaxis", description: Text("Tap + to add a snapshot"))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical)
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
        .sheet(item: $editState) { state in
            MacPortfolioEditView(portfolio: state.portfolio, debt: state.debt)
        }
    }

    private func monthName(_ month: Int, _ year: Int) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "\(month)/\(year)" }
        return fmt.string(from: date)
    }

    private func portfolioRow(_ label: String, value: Decimal) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(MoneyHelper.format(value))
        }
    }

    private func totalRow(_ label: String, value: Decimal, delta: Decimal?) -> some View {
        HStack {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            VStack(alignment: .trailing) {
                Text(MoneyHelper.format(value))
                if let d = delta {
                    Text(PortfolioStore.formatDelta(d))
                        .font(.caption)
                        .foregroundStyle(d >= 0 ? .green : .red)
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
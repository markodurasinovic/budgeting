import SwiftUI
import SwiftData
import BudgetingKit

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\PortfolioSnapshot.year), SortDescriptor(\PortfolioSnapshot.month)])
    private var portfolios: [PortfolioSnapshot]

    @Query(sort: [SortDescriptor(\DebtSnapshot.year), SortDescriptor(\DebtSnapshot.month)])
    private var debts: [DebtSnapshot]

    @State private var showEditor = false
    @State private var editingPortfolio: PortfolioSnapshot?
    @State private var editingDebt: DebtSnapshot?

    var body: some View {
        NavigationStack {
            PortfolioListView(portfolios: portfolios, debts: debts)
                .navigationTitle("Portfolio")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let month = Calendar.current.component(.month, from: Date())
                        let year = Calendar.current.component(.year, from: Date())
                        editingPortfolio = PortfolioStore.snapshotForMonth(month, year: year, context: modelContext)
                        editingDebt = PortfolioStore.debtForMonth(month, year: year, context: modelContext)
                        showEditor = true
                    } label: {
                        Label("Add Month", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                PortfolioEditView(portfolio: editingPortfolio!, debt: editingDebt ?? DebtSnapshot(month: editingPortfolio!.month, year: editingPortfolio!.year))
            }
        }
    }
}

struct PortfolioListView: View {
    let portfolios: [PortfolioSnapshot]
    let debts: [DebtSnapshot]

    var body: some View {
        let data = PortfolioStore.allRows(portfolios: portfolios, debts: debts)
        if data.isEmpty {
            ContentUnavailableView("No portfolio data", systemImage: "chart.line.uptrend.xyaxis", description: Text("Add your first monthly snapshot"))
        } else {
            List {
                PortfolioSectionsView(data: data)
            }
        }
    }
}

struct PortfolioSectionsView: View {
    let data: [PortfolioRow]

    var body: some View {
        ForEach(Array(data.enumerated()), id: \.element.portfolio.id) { _, row in
            Section(row.label) {
                PortfolioMonthRowView(row: row)
            }
        }
    }
}

struct PortfolioMonthRowView: View {
    let row: PortfolioRow

    var body: some View {
        Text("S&S ISA: \(MoneyHelper.format(row.portfolio.ssIsa))")
        Text("Cash ISA: \(MoneyHelper.format(row.portfolio.cashIsa))")
        Text("LISA: \(MoneyHelper.format(row.portfolio.lisa))")
        Text("Crypto: \(MoneyHelper.format(row.portfolio.crypto))")
        Divider()
        Text("Total (excl. pension): \(MoneyHelper.format(row.totalExPension))")
            .fontWeight(.semibold)
        Text("Pension: \(MoneyHelper.format(row.portfolio.pension))")
        Text("Grand Total: \(MoneyHelper.format(row.grandTotal))")
            .fontWeight(.semibold)
        if let notes = row.portfolio.notes.nilIfEmpty {
            Text("Notes: \(notes)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if let d = row.debt {
            Divider()
            Text("Debts").font(.subheadline).fontWeight(.semibold)
            Text("Chase: \(MoneyHelper.format(d.chase))")
            Text("Amex: \(MoneyHelper.format(d.amex))")
            Text("Other: \(MoneyHelper.format(d.other))")
            Text("Debt Total: \(MoneyHelper.format(row.debtTotal))")
                .fontWeight(.semibold)
            Divider()
            Text("Net Worth: \(MoneyHelper.format(row.netGrandWorth))")
                .fontWeight(.bold)
        }
    }
}

#Preview {
    PortfolioView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
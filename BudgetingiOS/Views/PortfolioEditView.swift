import SwiftUI
import SwiftData
import BudgetingKit

struct PortfolioEditView: View {
    @Environment(\.dismiss) private var dismiss

    let portfolio: PortfolioSnapshot
    let debt: DebtSnapshot

    @State private var ssIsaText = ""
    @State private var cashIsaText = ""
    @State private var lisaText = ""
    @State private var cryptoText = ""
    @State private var pensionText = ""
    @State private var notesText = ""
    @State private var chaseText = ""
    @State private var amexText = ""
    @State private var otherText = ""

    private var monthName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let components = DateComponents(year: portfolio.year, month: portfolio.month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "\(portfolio.month)/\(portfolio.year)" }
        return dateFormatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                investmentSection
                debtSection
                summarySection
            }
            .navigationTitle("Edit Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear(perform: loadValues)
        }
    }

    private var investmentSection: some View {
        Section("Investments — \(monthName)") {
            TextField("S&S ISA", text: $ssIsaText)
                .keyboardType(.decimalPad)
            TextField("Cash ISA", text: $cashIsaText)
                .keyboardType(.decimalPad)
            TextField("LISA", text: $lisaText)
                .keyboardType(.decimalPad)
            TextField("Crypto", text: $cryptoText)
                .keyboardType(.decimalPad)
            TextField("Pension", text: $pensionText)
                .keyboardType(.decimalPad)
            TextField("Notes", text: $notesText)
        }
    }

    private var debtSection: some View {
        Section("Debts — \(monthName)") {
            TextField("Chase", text: $chaseText)
                .keyboardType(.decimalPad)
            TextField("Amex", text: $amexText)
                .keyboardType(.decimalPad)
            TextField("Other", text: $otherText)
                .keyboardType(.decimalPad)
        }
    }

    private var summarySection: some View {
        let ss = MoneyHelper.parse(ssIsaText) ?? 0
        let ci = MoneyHelper.parse(cashIsaText) ?? 0
        let li = MoneyHelper.parse(lisaText) ?? 0
        let cr = MoneyHelper.parse(cryptoText) ?? 0
        let ch = MoneyHelper.parse(chaseText) ?? 0
        let am = MoneyHelper.parse(amexText) ?? 0
        let ot = MoneyHelper.parse(otherText) ?? 0
        let totalInv = ss + ci + li + cr
        let totalDebt = ch + am + ot

        return Section {
            HStack {
                Text("Investments Total")
                Spacer()
                Text(MoneyHelper.format(totalInv))
            }
            HStack {
                Text("Debt Total")
                Spacer()
                Text(MoneyHelper.format(totalDebt))
            }
            HStack {
                Text("Net Worth")
                    .fontWeight(.bold)
                Spacer()
                Text(MoneyHelper.format(totalInv - totalDebt))
                    .fontWeight(.bold)
            }
        }
    }

    private func loadValues() {
        ssIsaText = portfolio.ssIsa == 0 ? "" : MoneyHelper.format(portfolio.ssIsa).replacingOccurrences(of: "£", with: "")
        cashIsaText = portfolio.cashIsa == 0 ? "" : MoneyHelper.format(portfolio.cashIsa).replacingOccurrences(of: "£", with: "")
        lisaText = portfolio.lisa == 0 ? "" : MoneyHelper.format(portfolio.lisa).replacingOccurrences(of: "£", with: "")
        cryptoText = portfolio.crypto == 0 ? "" : MoneyHelper.format(portfolio.crypto).replacingOccurrences(of: "£", with: "")
        pensionText = portfolio.pension == 0 ? "" : MoneyHelper.format(portfolio.pension).replacingOccurrences(of: "£", with: "")
        notesText = portfolio.notes
        chaseText = debt.chase == 0 ? "" : MoneyHelper.format(debt.chase).replacingOccurrences(of: "£", with: "")
        amexText = debt.amex == 0 ? "" : MoneyHelper.format(debt.amex).replacingOccurrences(of: "£", with: "")
        otherText = debt.other == 0 ? "" : MoneyHelper.format(debt.other).replacingOccurrences(of: "£", with: "")
    }

    private func save() {
        portfolio.ssIsa = MoneyHelper.parse(ssIsaText) ?? 0
        portfolio.cashIsa = MoneyHelper.parse(cashIsaText) ?? 0
        portfolio.lisa = MoneyHelper.parse(lisaText) ?? 0
        portfolio.crypto = MoneyHelper.parse(cryptoText) ?? 0
        portfolio.pension = MoneyHelper.parse(pensionText) ?? 0
        portfolio.notes = notesText
        debt.chase = MoneyHelper.parse(chaseText) ?? 0
        debt.amex = MoneyHelper.parse(amexText) ?? 0
        debt.other = MoneyHelper.parse(otherText) ?? 0
        dismiss()
    }
}

#Preview {
    PortfolioEditView(portfolio: PortfolioSnapshot(month: 6, year: 2026), debt: DebtSnapshot(month: 6, year: 2026))
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
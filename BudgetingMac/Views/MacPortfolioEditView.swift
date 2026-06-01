import SwiftUI
import SwiftData
import BudgetingKit

struct MacPortfolioEditView: View {
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
        VStack(spacing: 16) {
            Text("Edit Portfolio — \(monthName)")
                .font(.headline)

            Form {
                Section("Investments") {
                    TextField("S&S ISA", text: $ssIsaText)
                    TextField("Cash ISA", text: $cashIsaText)
                    TextField("LISA", text: $lisaText)
                    TextField("Crypto", text: $cryptoText)
                    TextField("Pension", text: $pensionText)
                    TextField("Notes", text: $notesText)
                }
                Section("Debts") {
                    TextField("Chase", text: $chaseText)
                    TextField("Amex", text: $amexText)
                    TextField("Other", text: $otherText)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 400, height: 480)
        .onAppear(perform: loadValues)
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
    MacPortfolioEditView(portfolio: PortfolioSnapshot(month: 6, year: 2026), debt: DebtSnapshot(month: 6, year: 2026))
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
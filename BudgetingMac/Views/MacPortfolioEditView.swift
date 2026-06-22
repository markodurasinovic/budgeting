import SwiftUI
import SwiftData
import BudgetingKit

/// Sheet for editing a single month's portfolio and debt snapshots. Loads the
/// current values on appear (showing empty fields for zero balances), and writes
/// the parsed values back to both snapshots on save.
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
        DateFormatting.monthYear(month: portfolio.month, year: portfolio.year)
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

    /// Populates the text fields from the snapshots, leaving a field empty when
    /// the stored balance is zero (so new months don't show a sea of `£0`).
    private func loadValues() {
        ssIsaText = formatPlainIfNonZero(portfolio.ssIsa)
        cashIsaText = formatPlainIfNonZero(portfolio.cashIsa)
        lisaText = formatPlainIfNonZero(portfolio.lisa)
        cryptoText = formatPlainIfNonZero(portfolio.crypto)
        pensionText = formatPlainIfNonZero(portfolio.pension)
        notesText = portfolio.notes
        chaseText = formatPlainIfNonZero(debt.chase)
        amexText = formatPlainIfNonZero(debt.amex)
        otherText = formatPlainIfNonZero(debt.other)
    }

    private func formatPlainIfNonZero(_ value: Decimal) -> String {
        value == 0 ? "" : MoneyHelper.formatPlain(value)
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

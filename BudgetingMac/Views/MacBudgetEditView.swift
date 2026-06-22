import SwiftUI
import SwiftData
import BudgetingKit

/// Sheet for editing a single month's budget envelope (income, bills, savings,
/// investment). Shows a live remainder and savings rate as the user types, then
/// writes the parsed values back to the `MonthlyBudget` on save.
struct MacBudgetEditView: View {
    @Environment(\.dismiss) private var dismiss

    let budget: MonthlyBudget

    @State private var incomeText = ""
    @State private var savingsText = ""
    @State private var investmentText = ""
    @State private var billsText = ""

    /// Parses `text` as a `Decimal`, defaulting to `0` for empty/invalid input
    /// so the live calculations below never surface an optional.
    private func parsed(_ text: String) -> Decimal {
        MoneyHelper.parse(text) ?? 0
    }

    private var remainder: Decimal {
        BudgetStore.remainder(
            income: parsed(incomeText), expenses: 0,
            bills: parsed(billsText), savings: parsed(savingsText),
            investment: parsed(investmentText)
        )
    }

    private var savingsRateValue: Decimal? {
        BudgetStore.savingsRate(
            savings: parsed(savingsText), investment: parsed(investmentText),
            income: parsed(incomeText), remainder: remainder
        )
    }

    private var totalSaved: Decimal {
        parsed(savingsText) + parsed(investmentText) + remainder
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Monthly Budget")
                .font(.headline)

            Form {
                TextField("Income", text: $incomeText)
                TextField("Bills", text: $billsText)
                TextField("Savings", text: $savingsText)
                TextField("Investment", text: $investmentText)
            }
            .formStyle(.grouped)

            VStack(spacing: 4) {
                HStack {
                    Text("Total saved:")
                    Spacer()
                    Text(MoneyHelper.format(totalSaved))
                }
                HStack {
                    Text("Savings rate:")
                    Spacer()
                    Text(MoneyHelper.formatPercent(savingsRateValue))
                        .foregroundStyle(savingsRateValue == nil ? .secondary : .primary)
                }
            }
            .padding(.horizontal)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    budget.income = parsed(incomeText)
                    budget.bills = parsed(billsText)
                    budget.savings = parsed(savingsText)
                    budget.investment = parsed(investmentText)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(incomeText.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 350, height: 380)
        .onAppear {
            incomeText = budget.income == 0 ? "" : MoneyHelper.formatPlain(budget.income)
            billsText = budget.bills == 0 ? "" : MoneyHelper.formatPlain(budget.bills)
            savingsText = budget.savings == 0 ? "" : MoneyHelper.formatPlain(budget.savings)
            investmentText = budget.investment == 0 ? "" : MoneyHelper.formatPlain(budget.investment)
        }
    }
}

#Preview {
    MacBudgetEditView(budget: MonthlyBudget(month: 5, year: 2026, income: 3500, savings: 500, investment: 200, bills: 1000))
        .modelContainer(BudgetingContainer.makePreviewContainer())
}

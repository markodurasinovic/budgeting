import SwiftUI
import SwiftData
import BudgetingKit

struct MacBudgetEditView: View {
    @Environment(\.dismiss) private var dismiss

    @Query private var entries: [Entry]
    @Query private var budgets: [MonthlyBudget]

    let budget: MonthlyBudget

    @State private var incomeText = ""
    @State private var savingsText = ""
    @State private var investmentText = ""
    @State private var billsText = ""

    private var remainder: Decimal {
        BudgetStore.remainder(income: MoneyHelper.parse(incomeText) ?? 0, expenses: 0, bills: MoneyHelper.parse(billsText) ?? 0, savings: MoneyHelper.parse(savingsText) ?? 0, investment: MoneyHelper.parse(investmentText) ?? 0)
    }

    private var savingsRateValue: Decimal? {
        BudgetStore.savingsRate(
            savings: MoneyHelper.parse(savingsText) ?? 0,
            investment: MoneyHelper.parse(investmentText) ?? 0,
            income: MoneyHelper.parse(incomeText) ?? 0,
            remainder: remainder
        )
    }

    private var carryover: Decimal {
        BudgetStore.carryover(month: budget.month, year: budget.year, entries: entries, budgets: budgets)
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
                     Text(MoneyHelper.format((MoneyHelper.parse(savingsText) ?? 0) + (MoneyHelper.parse(investmentText) ?? 0) + remainder))
                }
                HStack {
                    Text("Savings rate:")
                    Spacer()
                    if let rate = savingsRateValue {
                        Text(String(format: "%.1f%%", NSDecimalNumber(decimal: rate * 100).doubleValue))
                    } else {
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            if carryover != 0 {
                Text(carryover > 0
                     ? "\(MoneyHelper.format(carryover)) surplus carried over from last month"
                     : "Last month ended \(MoneyHelper.format(carryover)) — consider reducing savings/investment")
                    .font(.caption)
                    .foregroundStyle(carryover > 0 ? .green : .red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    budget.income = MoneyHelper.parse(incomeText) ?? 0
                    budget.bills = MoneyHelper.parse(billsText) ?? 0
                    budget.savings = MoneyHelper.parse(savingsText) ?? 0
                    budget.investment = MoneyHelper.parse(investmentText) ?? 0
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(incomeText.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 350, height: 420)
        .onAppear {
            incomeText = budget.income == 0 ? "" : MoneyHelper.format(budget.income).replacingOccurrences(of: "£", with: "")
            billsText = budget.bills == 0 ? "" : MoneyHelper.format(budget.bills).replacingOccurrences(of: "£", with: "")
            savingsText = budget.savings == 0 ? "" : MoneyHelper.format(budget.savings).replacingOccurrences(of: "£", with: "")
            investmentText = budget.investment == 0 ? "" : MoneyHelper.format(budget.investment).replacingOccurrences(of: "£", with: "")
        }
    }
}

#Preview {
    MacBudgetEditView(budget: MonthlyBudget(month: 5, year: 2026, income: 3500, savings: 500, investment: 200, bills: 1000))
        .modelContainer(BudgetingContainer.makePreviewContainer())
}

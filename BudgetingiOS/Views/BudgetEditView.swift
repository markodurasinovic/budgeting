import SwiftUI
import SwiftData
import BudgetingKit

struct BudgetEditView: View {
    @Environment(\.dismiss) private var dismiss

    let budget: MonthlyBudget

    @State private var incomeText = ""
    @State private var savingsText = ""
    @State private var investmentText = ""
    @State private var billsText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly Budget") {
                    TextField("Income", text: $incomeText)
                        .keyboardType(.decimalPad)
                    TextField("Bills", text: $billsText)
                        .keyboardType(.decimalPad)
                    TextField("Savings", text: $savingsText)
                        .keyboardType(.decimalPad)
                    TextField("Investment", text: $investmentText)
                        .keyboardType(.decimalPad)
                }

                Section {
                    let remainder = BudgetStore.remainder(
                        income: MoneyHelper.parse(incomeText) ?? 0,
                        expenses: 0,
                        bills: MoneyHelper.parse(billsText) ?? 0,
                        savings: MoneyHelper.parse(savingsText) ?? 0,
                        investment: MoneyHelper.parse(investmentText) ?? 0
                    )
                    let totalSaved = (MoneyHelper.parse(savingsText) ?? 0) + (MoneyHelper.parse(investmentText) ?? 0) + remainder
                    let rate = BudgetStore.savingsRate(
                        savings: MoneyHelper.parse(savingsText) ?? 0,
                        investment: MoneyHelper.parse(investmentText) ?? 0,
                        income: MoneyHelper.parse(incomeText) ?? 0,
                        remainder: remainder
                    )

                    HStack {
                        Text("Total saved")
                        Spacer()
                        Text(MoneyHelper.format(totalSaved))
                            .foregroundStyle(totalSaved < 0 ? .red : .primary)
                    }

                    if let rate = rate {
                        HStack {
                            Text("Savings rate")
                            Spacer()
                            Text(String(format: "%.1f%%", NSDecimalNumber(decimal: rate * 100).doubleValue))
                        }
                    }
                }
            }
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBudget()
                    }
                    .disabled(incomeText.isEmpty)
                }
            }
            .onAppear {
                incomeText = budget.income == 0 ? "" : MoneyHelper.format(budget.income).replacingOccurrences(of: "£", with: "")
                billsText = budget.bills == 0 ? "" : MoneyHelper.format(budget.bills).replacingOccurrences(of: "£", with: "")
                savingsText = budget.savings == 0 ? "" : MoneyHelper.format(budget.savings).replacingOccurrences(of: "£", with: "")
                investmentText = budget.investment == 0 ? "" : MoneyHelper.format(budget.investment).replacingOccurrences(of: "£", with: "")
            }
        }
    }

    private func saveBudget() {
        budget.income = MoneyHelper.parse(incomeText) ?? 0
        budget.bills = MoneyHelper.parse(billsText) ?? 0
        budget.savings = MoneyHelper.parse(savingsText) ?? 0
        budget.investment = MoneyHelper.parse(investmentText) ?? 0
        dismiss()
    }
}
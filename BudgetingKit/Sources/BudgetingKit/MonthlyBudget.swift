import Foundation
import SwiftData

/// The monthly budget envelope: income and the four named allocations.
///
/// One row per `(month, year)`. Created on demand by
/// `BudgetStore.budgetForMonth`. `remainder` is not stored — it is derived as
/// `income - expenses - bills - savings - investment` (see `BudgetStore.remainder`).
///
/// All fields are `Decimal` for money precision. Defaults are `0` so a freshly
/// created month is a valid empty budget.
@Model
final public class MonthlyBudget {
    public var id: UUID
    public var month: Int
    public var year: Int
    public var income: Decimal
    public var savings: Decimal
    public var investment: Decimal
    public var bills: Decimal

    public init(
        id: UUID = UUID(),
        month: Int,
        year: Int,
        income: Decimal = 0,
        savings: Decimal = 0,
        investment: Decimal = 0,
        bills: Decimal = 0
    ) {
        self.id = id
        self.month = month
        self.year = year
        self.income = income
        self.savings = savings
        self.investment = investment
        self.bills = bills
    }
}

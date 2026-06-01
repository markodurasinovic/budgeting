import Foundation
import SwiftData

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
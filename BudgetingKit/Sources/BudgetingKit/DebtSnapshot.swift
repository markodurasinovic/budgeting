import Foundation
import SwiftData

/// A month-end snapshot of outstanding debt balances across cards/accounts.
///
/// Paired with a `PortfolioSnapshot` for the same `(month, year)` via
/// `PortfolioRow` in `PortfolioStore`. Stored as a separate model so a month can
/// have investments without debts (and vice versa), and so net-worth math can
/// treat debt as an optional subtraction.
///
/// Fields:
/// - `chase`: Chase card balance
/// - `amex`: Amex card balance
/// - `other`: Any other debt not captured above
@Model
final public class DebtSnapshot {
    public var id: UUID
    public var month: Int
    public var year: Int
    public var chase: Decimal
    public var amex: Decimal
    public var other: Decimal

    public init(
        id: UUID = UUID(),
        month: Int,
        year: Int,
        chase: Decimal = 0,
        amex: Decimal = 0,
        other: Decimal = 0
    ) {
        self.id = id
        self.month = month
        self.year = year
        self.chase = chase
        self.amex = amex
        self.other = other
    }
}

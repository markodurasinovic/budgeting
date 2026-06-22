import Foundation
import SwiftData

/// A month-end snapshot of investment balances across accounts.
///
/// One row per `(month, year)`. Created on demand by
/// `PortfolioStore.snapshotForMonth`. Free-text `notes` store any commentary for
/// the month. The `PortfolioRow` view-model in `PortfolioStore` derives display
/// values (totals, net worth) from a snapshot paired with an optional
/// `DebtSnapshot` for the same month.
///
/// Fields:
/// - `ssIsa`: Stocks & Shares ISA balance
/// - `cashIsa`: Cash ISA balance
/// - `lisa`: Lifetime ISA balance
/// - `crypto`: Crypto holdings value
/// - `pension`: Pension balance (excluded from `totalExPension` in `PortfolioRow`)
@Model
final public class PortfolioSnapshot {
    public var id: UUID
    public var month: Int
    public var year: Int
    public var ssIsa: Decimal
    public var cashIsa: Decimal
    public var lisa: Decimal
    public var crypto: Decimal
    public var pension: Decimal
    public var notes: String

    public init(
        id: UUID = UUID(),
        month: Int,
        year: Int,
        ssIsa: Decimal = 0,
        cashIsa: Decimal = 0,
        lisa: Decimal = 0,
        crypto: Decimal = 0,
        pension: Decimal = 0,
        notes: String = ""
    ) {
        self.id = id
        self.month = month
        self.year = year
        self.ssIsa = ssIsa
        self.cashIsa = cashIsa
        self.lisa = lisa
        self.crypto = crypto
        self.pension = pension
        self.notes = notes
    }
}

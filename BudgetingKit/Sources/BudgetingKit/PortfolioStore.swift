import Foundation
import SwiftData

/// A view-model row pairing a `PortfolioSnapshot` with its optional `DebtSnapshot`
/// for the same month, plus derived display values (totals, net worth).
public struct PortfolioRow: Identifiable {
    public var id: UUID { portfolio.id }
    public let portfolio: PortfolioSnapshot
    public let debt: DebtSnapshot?

    /// Display label like `"April 2026"`, derived from the snapshot's month/year.
    public var label: String {
        DateFormatting.monthYear(month: portfolio.month, year: portfolio.year)
    }

    /// Sum of all investments except pension.
    public var totalExPension: Decimal {
        portfolio.ssIsa + portfolio.cashIsa + portfolio.lisa + portfolio.crypto
    }

    /// Sum of all investments including pension.
    public var grandTotal: Decimal {
        totalExPension + portfolio.pension
    }

    /// Sum of all debts, or `0` when there's no debt snapshot.
    public var debtTotal: Decimal {
        debt.map { $0.chase + $0.amex + $0.other } ?? Decimal(0)
    }

    /// Investments minus debts, excluding pension.
    public var netWorth: Decimal {
        totalExPension - debtTotal
    }

    /// Investments minus debts, including pension.
    public var netGrandWorth: Decimal {
        grandTotal - debtTotal
    }
}

/// Editable reference to a portfolio + debt pair for the edit sheet. Wrapped in
/// a struct with a stable `id` so SwiftUI can drive a `.sheet(item:)` from it.
public struct PortfolioEditState: Identifiable {
    public let id = UUID()
    public let portfolio: PortfolioSnapshot
    public let debt: DebtSnapshot

    public init(portfolio: PortfolioSnapshot, debt: DebtSnapshot) {
        self.portfolio = portfolio
        self.debt = debt
    }
}

/// Stateless operations on portfolio and debt snapshots: per-month lookup,
/// row assembly, and delta formatting.
public enum PortfolioStore {
    /// Fetches the `PortfolioSnapshot` for `(month, year)`, creating an empty
    /// one if none exists (and inserting it so it can be edited in place).
    public static func snapshotForMonth(_ month: Int, year: Int, context: ModelContext) -> PortfolioSnapshot {
        let descriptor = FetchDescriptor<PortfolioSnapshot>(predicate: #Predicate { $0.month == month && $0.year == year })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let snap = PortfolioSnapshot(month: month, year: year)
        context.insert(snap)
        return snap
    }

    /// Fetches the `DebtSnapshot` for `(month, year)`, creating an empty one if
    /// none exists (and inserting it so it can be edited in place).
    public static func debtForMonth(_ month: Int, year: Int, context: ModelContext) -> DebtSnapshot {
        let descriptor = FetchDescriptor<DebtSnapshot>(predicate: #Predicate { $0.month == month && $0.year == year })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let debt = DebtSnapshot(month: month, year: year)
        context.insert(debt)
        return debt
    }

    /// Pairs each portfolio with its matching debt (by `year-month`) and sorts
    /// the rows newest-first.
    public static func allRows(portfolios: [PortfolioSnapshot], debts: [DebtSnapshot]) -> [PortfolioRow] {
        let debtMap = Dictionary(uniqueKeysWithValues: debts.map { ("\($0.year)-\($0.month)", $0) })
        return portfolios
            .sorted { ($0.year, $0.month) > ($1.year, $1.month) }
            .map { PortfolioRow(portfolio: $0, debt: debtMap["\($0.year)-\($0.month)"]) }
    }

    /// Absolute change: `current - previous`.
    public static func delta(current: Decimal, previous: Decimal) -> Decimal {
        current - previous
    }

    /// Relative change as a fraction: `(current - previous) / previous`.
    /// Returns `nil` when `previous` is `0` (the percentage is undefined).
    public static func deltaPercent(current: Decimal, previous: Decimal) -> Decimal? {
        guard previous != 0 else { return nil }
        return (current - previous) / previous
    }

    /// Formats `value` with a sign prefix, e.g. `+£125.50`, `-£40.00`. When
    /// `showSign` is false, the value is shown unsigned.
    public static func formatDelta(_ value: Decimal, showSign: Bool = true) -> String {
        let formatted = MoneyHelper.format(abs(value))
        if showSign {
            return value >= 0 ? "+\(formatted)" : "-\(formatted)"
        }
        return formatted
    }

    /// Formats a delta ratio (e.g. `0.125`) as a signed percentage string with
    /// 2 fractional digits, e.g. `+12.50%` / `-4.00%`. Returns `"—"` when the
    /// ratio is nil. Uses a leading sign because deltas are directional.
    public static func formatDeltaPercent(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        let pct = NSDecimalNumber(decimal: value * 100).doubleValue
        return String(format: "%+.2f%%", pct)
    }
}

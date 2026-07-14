import Foundation
import SwiftData

public struct PortfolioRow: Identifiable {
    public var id: UUID { portfolio.id }
    public let portfolio: PortfolioSnapshot
    public let debt: DebtSnapshot?

    public var label: String {
        Formatters.monthYearString(month: portfolio.month, year: portfolio.year)
    }

    public var totalExPension: Decimal {
        portfolio.ssIsa + portfolio.cashIsa + portfolio.lisa + portfolio.crypto
    }

    public var grandTotal: Decimal {
        totalExPension + portfolio.pension
    }

    public var debtTotal: Decimal {
        debt.map { $0.chase + $0.amex + $0.other } ?? Decimal(0)
    }

    public var netWorth: Decimal {
        totalExPension - debtTotal
    }

    public var netGrandWorth: Decimal {
        grandTotal - debtTotal
    }
}

public struct PortfolioEditState: Identifiable {
    public let id = UUID()
    public let portfolio: PortfolioSnapshot
    public let debt: DebtSnapshot
    public let previousPortfolio: PortfolioSnapshot?
    public let previousDebt: DebtSnapshot?

    public init(portfolio: PortfolioSnapshot, debt: DebtSnapshot, previousPortfolio: PortfolioSnapshot? = nil, previousDebt: DebtSnapshot? = nil) {
        self.portfolio = portfolio
        self.debt = debt
        self.previousPortfolio = previousPortfolio
        self.previousDebt = previousDebt
    }
}

public enum PortfolioStore {
    public static func snapshotForMonth(_ month: Int, year: Int, context: ModelContext) -> PortfolioSnapshot {
        let descriptor = FetchDescriptor<PortfolioSnapshot>(predicate: #Predicate { $0.month == month && $0.year == year })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let snap = PortfolioSnapshot(month: month, year: year)
        context.insert(snap)
        return snap
    }

    public static func debtForMonth(_ month: Int, year: Int, context: ModelContext) -> DebtSnapshot {
        let descriptor = FetchDescriptor<DebtSnapshot>(predicate: #Predicate { $0.month == month && $0.year == year })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let debt = DebtSnapshot(month: month, year: year)
        context.insert(debt)
        return debt
    }

    public static func existingSnapshot(month: Int, year: Int, context: ModelContext) -> PortfolioSnapshot? {
        let descriptor = FetchDescriptor<PortfolioSnapshot>(predicate: #Predicate { $0.month == month && $0.year == year })
        return try? context.fetch(descriptor).first
    }

    public static func existingDebt(month: Int, year: Int, context: ModelContext) -> DebtSnapshot? {
        let descriptor = FetchDescriptor<DebtSnapshot>(predicate: #Predicate { $0.month == month && $0.year == year })
        return try? context.fetch(descriptor).first
    }

    public static func previousMonth(for month: Int, year: Int) -> (month: Int, year: Int) {
        month == 1 ? (12, year - 1) : (month - 1, year)
    }

    public static func allRows(portfolios: [PortfolioSnapshot], debts: [DebtSnapshot]) -> [PortfolioRow] {
        let debtMap = Dictionary(uniqueKeysWithValues: debts.map { ("\($0.year)-\($0.month)", $0) })
        return portfolios
            .sorted { ($0.year, $0.month) > ($1.year, $1.month) }
            .map { PortfolioRow(portfolio: $0, debt: debtMap["\($0.year)-\($0.month)"]) }
    }

    public static func delta(current: Decimal, previous: Decimal) -> Decimal {
        current - previous
    }

    public static func deltaPercent(current: Decimal, previous: Decimal) -> Decimal? {
        guard previous != 0 else { return nil }
        return (current - previous) / previous
    }

    public static func formatDelta(_ value: Decimal, showSign: Bool = true) -> String {
        let formatted = MoneyHelper.format(abs(value))
        if showSign {
            return value >= 0 ? "+\(formatted)" : "-\(formatted)"
        }
        return formatted
    }

    public static func formatDeltaPercent(_ value: Decimal?) -> String {
        guard let v = value else { return "—" }
        let pct = NSDecimalNumber(decimal: v * 100).doubleValue
        return String(format: "%+.2f%%", pct)
    }
}
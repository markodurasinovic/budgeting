import Foundation
import SwiftData

public struct PortfolioRow: Identifiable {
    public var id: UUID { portfolio.id }
    public let portfolio: PortfolioSnapshot
    public let debt: DebtSnapshot?

    public var label: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let components = DateComponents(year: portfolio.year, month: portfolio.month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "\(portfolio.month)/\(portfolio.year)" }
        return dateFormatter.string(from: date)
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

    public init(portfolio: PortfolioSnapshot, debt: DebtSnapshot) {
        self.portfolio = portfolio
        self.debt = debt
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
import Foundation
import SwiftData

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
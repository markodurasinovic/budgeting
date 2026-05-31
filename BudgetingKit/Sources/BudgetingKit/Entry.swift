import Foundation
import SwiftData

@Model
final public class Entry {
    public var id: UUID
    public var date: Date
    public var item: String
    public var tag: String
    public var amount: Decimal

    public init(
        id: UUID = UUID(),
        date: Date = .now,
        item: String,
        tag: String,
        amount: Decimal
    ) {
        self.id = id
        self.date = date
        self.item = item
        self.tag = tag
        self.amount = amount
    }
}
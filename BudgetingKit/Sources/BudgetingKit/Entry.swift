import Foundation
import SwiftData

/// A single recorded income or expense line item.
///
/// `@Model` is a SwiftData macro: it turns this `class` into a persisted entity
/// that SwiftData can store in an SQLite database and sync via CloudKit. The
/// `final public` modifiers make it non-overrideable and visible from the app
/// targets that import `BudgetingKit`.
///
/// Conventions:
/// - `amount` is a `Decimal` (not `Double`) to avoid floating-point rounding on
///   money. Negative amounts represent expenses; positive amounts represent
///   income. Whether a value is "income" or "expense" is inferred from the sign
///   and the tag, not stored as a separate enum — see `BudgetStore` for the
///   aggregation logic.
/// - `tag` is a plain `String` (not a relationship to `Tag`) so that deleting a
///   tag never cascades to entries. The `Tag` table acts as a color/registry
///   layer; entries own their tag name verbatim.
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

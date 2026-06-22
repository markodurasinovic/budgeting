import Foundation
import SwiftData

/// A registry entry for a tag, storing its display color as a hex string.
///
/// `Tag` records are created lazily by `BudgetStore.resolveTag` whenever an
/// entry uses a new tag name, and removed by `BudgetStore.removeOrphanTag` when
/// no entries reference the name anymore. Colors are assigned at launch by
/// `BudgetStore.assignTagColors`, which maps sorted tag names onto `TagPalette`.
///
/// `Entry` does not hold a relationship to `Tag`; it stores the tag *name* as a
/// string. This keeps entry creation cheap and avoids cascade-delete surprises.
@Model
final public class Tag {
    public var id: UUID
    public var name: String
    public var colorHex: String

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = ""
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

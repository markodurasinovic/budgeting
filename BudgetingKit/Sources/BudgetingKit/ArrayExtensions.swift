import Foundation

/// Small extensions on standard-library types that make call sites more
/// readable. Kept in one place so they're easy to discover.

public extension Array {
    /// Bounds-checked subscript. Returns `nil` when `index` is out of range,
    /// instead of trapping. Mirrors the safe-access pattern common in JS/TS.
    /// Example: `row[safe: 4]` instead of guarding `row.count > 4` everywhere.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

public extension String {
    /// Returns `nil` when the string is empty, otherwise the string itself.
    /// Useful for turning a trimmed string into an optional tag value:
    /// `tag.trimmingCharacters(in: .whitespaces).nilIfEmpty`.
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

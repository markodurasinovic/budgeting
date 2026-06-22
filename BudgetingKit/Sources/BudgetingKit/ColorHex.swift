import SwiftUI

/// Color helpers for converting hex strings (e.g. `#FF6B35`) into SwiftUI `Color`
/// values, and for deriving a stable color for a tag name when no explicit color
/// is stored.
public extension Color {
    /// Returns the color for a tag, preferring a stored hex value and falling back
    /// to a deterministic color derived from the tag name.
    static func hex(_ tagName: String, from hexString: String?) -> Color {
        if let hex = hexString, !hex.isEmpty {
            return Color(hex: hex)
        }
        return Color.tagColor(for: tagName)
    }

    /// Initializes a `Color` from a hex string. Supports `#RRGGBB`, `RRGGBB`,
    /// `#AARRGGBB`, and `AARRGGBB`. Invalid input falls back to opaque black.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Derives a deterministic color for a tag name. The same name always maps to
    /// the same color across launches (uses a stable hash, not `String.hashValue`
    /// which is randomized per run).
    static func tagColor(for name: String) -> Color {
        Color(hex: TagPalette.hex(for: name))
    }
}

/// The shared 60-color palette used to assign colors to tags.
///
/// This is the single source of truth: `BudgetStore` reads it when assigning
/// colors to tags at startup, and `Color.tagColor(for:)` reads it when rendering
/// a tag with no stored color. Defined here so the palette lives next to the
/// color code that consumes it.
public enum TagPalette {
    /// The ordered palette, from reds through greens, blues, purples, and muted tones.
    public static let colors: [String] = [
        "#E52222", "#E55C22", "#E59722", "#E5D122", "#BEE522",
        "#83E522", "#49E522", "#22E535", "#22E570", "#22E5AA",
        "#22E5E5", "#22AAE5", "#2270E5", "#2235E5", "#4922E5",
        "#8322E5", "#BE22E5", "#E522D1", "#E52297", "#E5225C",
        "#B23E3E", "#B2613E", "#B2843E", "#B2A63E", "#9BB23E",
        "#78B23E", "#55B23E", "#3EB24A", "#3EB26C", "#3EB28F",
        "#3EB2B2", "#3E8FB2", "#3E6CB2", "#3E4AB2", "#553EB2",
        "#783EB2", "#9B3EB2", "#B23EA6", "#B23E84", "#B23E61",
        "#8C4646", "#8C5B46", "#8C7046", "#8C8546", "#7E8C46",
        "#698C46", "#548C46", "#468C4D", "#468C62", "#468C77",
        "#468C8C", "#46778C", "#46628C", "#464D8C", "#54468C",
        "#69468C", "#7E468C", "#8C4685", "#8C4670", "#8C465B",
    ]

    /// Returns the palette color at `index`, wrapping modulo the palette size.
    public static func color(at index: Int) -> String {
        colors[((index % colors.count) + colors.count) % colors.count]
    }

    /// Returns a stable hex color for `name`. The hash is computed from the
    /// lowercased, sorted characters of the name so it is independent of letter
    /// case and unaffected by Swift's per-launch hash randomization. The hash
    /// uses wrapping arithmetic (`&*`/`&+`) so it can produce any `Int` value;
    /// the modulo-by-palette-size step is careful to avoid the `abs(Int.min)`
    /// trap by using signed-safe arithmetic.
    public static func hex(for name: String) -> String {
        let sorted = name.lowercased().sorted()
        var hash = 0
        for ch in sorted {
            hash = (hash &* 31) &+ Int(ch.asciiValue ?? 0)
        }
        // Use signed-safe modulo to avoid abs(Int.min) trapping. Adding
        // colors.count before the second modulo maps negative values into range
        // without calling abs().
        let count = colors.count
        let index = ((hash % count) + count) % count
        return colors[index]
    }
}

import SwiftUI

public extension Color {
    static func hex(_ tagName: String, from hexString: String?) -> Color {
        if let hex = hexString, !hex.isEmpty {
            return Color(hex: hex)
        }
        return Color.tagColor(for: tagName)
    }

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

    static func tagColor(for name: String) -> Color {
        let palette: [String] = [
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
        let sorted = name.lowercased().sorted()
        var hash = 0
        for ch in sorted {
            hash = (hash &* 31) &+ Int(ch.asciiValue ?? 0)
        }
        return Color(hex: palette[abs(hash) % palette.count])
    }
}
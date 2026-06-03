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
        let palette: [Color] = [
            .blue, .orange, .green, .purple, .pink,
            .teal, .indigo, .yellow, .mint, .cyan,
        ]
        var hash = 0
        for ch in name.utf8 {
            hash = (hash &* 31) &+ Int(ch)
        }
        return palette[abs(hash) % palette.count]
    }
}
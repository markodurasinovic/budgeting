import Foundation

public enum MoneyHelper {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    public static func format(_ amount: Decimal) -> String {
        let absAmount = abs(amount)
        let sign = amount < 0 ? "-£" : "£"
        let formatted = formatter.string(from: absAmount as NSNumber) ?? "\(absAmount)"
        return "\(sign)\(formatted)"
    }

    public static func parse(_ input: String) -> Decimal? {
        let cleaned = input
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: ",", with: "")

        guard !cleaned.isEmpty else { return nil }

        return Decimal(string: cleaned, locale: Locale(identifier: "en_GB"))
            ?? Decimal(string: cleaned)
    }
}
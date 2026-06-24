import Foundation
import JavaScriptCore

public enum MoneyHelper {
    private static let jsContext: JSContext? = JSContext()

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

        let isExpression = cleaned.contains(where: { c in
            "+*/".contains(c) || (c == "-" && cleaned.index(of: "-") != cleaned.startIndex)
        })

        if !isExpression {
            return Decimal(string: cleaned, locale: Locale(identifier: "en_GB"))
                ?? Decimal(string: cleaned)
        }

        return evaluateExpression(cleaned)
    }

    private static func evaluateExpression(_ expr: String) -> Decimal? {
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
        guard expr.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        guard let context = jsContext else { return nil }
        guard let result = context.evaluateScript(expr), result.isNumber else {
            return nil
        }
        return Decimal(result.toDouble())
    }
}
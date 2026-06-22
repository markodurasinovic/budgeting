import Foundation

/// Formatting and parsing for money amounts expressed in British pounds (£ GBP).
///
/// `format` turns a `Decimal` into a display string like `£1,250.50` or `-£7.50`.
/// `parse` accepts plain numbers (`1250`), pound-prefixed values (`£12.50`),
/// comma-grouped values (`1,250`), and arithmetic expressions (`12.50 + 3.75 * 2`)
/// — useful for the quick-entry amount field. Expressions are evaluated with a
/// small built-in parser, so there is no external dependency on a JS engine.
public enum MoneyHelper {
    /// Shared formatter used by `format`. Configured once and reused because
    /// `NumberFormatter` is expensive to construct.
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    /// Formats `amount` as a currency string with a leading `£` and a `-` for
    /// negative values, e.g. `£1,250.50`, `-£7.5`, `£0`.
    public static func format(_ amount: Decimal) -> String {
        let absAmount = abs(amount)
        let sign = amount < 0 ? "-£" : "£"
        let formatted = formatter.string(from: absAmount as NSNumber) ?? "\(absAmount)"
        return "\(sign)\(formatted)"
    }

    /// Formats `amount` without the currency symbol, for use in text fields where
    /// the user types a plain number. e.g. `1,250.50`, `-7.5`, `0`.
    public static func formatPlain(_ amount: Decimal) -> String {
        let absAmount = abs(amount)
        let sign = amount < 0 ? "-" : ""
        let formatted = formatter.string(from: absAmount as NSNumber) ?? "\(absAmount)"
        return "\(sign)\(formatted)"
    }

    /// Formats a ratio (e.g. `0.125`) as an unsigned percentage string with
    /// `digits` fractional digits, e.g. `12.5%`. Returns `"—"` when `value` is
    /// nil. Use `PortfolioStore.formatDeltaPercent` instead when a signed
    /// percentage (with a leading `+`/`-`) is wanted.
    public static func formatPercent(_ value: Decimal?, fractionDigits: Int = 1) -> String {
        guard let value else { return "—" }
        let pct = NSDecimalNumber(decimal: value * 100).doubleValue
        let pattern = "%.\(fractionDigits)f%%"
        return String(format: pattern, pct)
    }

    /// Parses user input into a `Decimal`.
    ///
    /// Accepts: `1250`, `£12.50`, `1,250`, `-7.5`, `12.50 + 3.75 * 2`,
    /// `(10 - 2) / 4`. Returns `nil` for empty, whitespace-only, or invalid input.
    /// Expressions support `+ - * /`, parentheses, and unary minus. Division by
    /// zero yields `nil`.
    public static func parse(_ input: String) -> Decimal? {
        let cleaned = input
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: ",", with: "")

        guard !cleaned.isEmpty else { return nil }

        // Detect an expression: any operator/paren character. We must check
        // before trying `Decimal(string:)` because it parses a leading numeric
        // prefix and ignores the rest, so "12.50 + 3.75" would otherwise be
        // read as "12.50". A leading `-` or `+` is also an operator (unary),
        // but the expression parser handles those correctly too.
        let isExpression = cleaned.contains { c in "+-*/()".contains(c) }

        if isExpression {
            return ExpressionEvaluator.evaluate(cleaned)
        }
        // Plain number. The locale fallback handles inputs that en_GB rejects.
        return Decimal(string: cleaned, locale: Locale(identifier: "en_GB"))
            ?? Decimal(string: cleaned)
    }
}

/// A tiny recursive-descent evaluator for arithmetic expressions, used by
/// `MoneyHelper.parse`. Supports `+ - * /`, parentheses, and unary `-`/`+`.
///
/// Grammar:
/// ```
/// expression = term (('+' | '-') term)*
/// term       = factor (('*' | '/') factor)*
/// factor     = number | '(' expression ')' | ('+' | '-') factor
/// ```
private enum ExpressionEvaluator {
    static func evaluate(_ source: String) -> Decimal? {
        let tokens = Tokenizer.tokenize(source)
        guard !tokens.isEmpty else { return nil }
        var parser = Parser(tokens: tokens)
        guard let value = parser.parseExpression(),
              parser.isAtEnd else { return nil }
        return value
    }
}

private enum Token: Equatable {
    case number(Decimal)
    case plus
    case minus
    case times
    case divide
    case lparen
    case rparen
}

private enum Tokenizer {
    static func tokenize(_ source: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(source)
        var i = 0

        while i < chars.count {
            let ch = chars[i]
            if ch.isWhitespace { i += 1; continue }

            switch ch {
            case "+": tokens.append(.plus); i += 1
            case "-": tokens.append(.minus); i += 1
            case "*": tokens.append(.times); i += 1
            case "/": tokens.append(.divide); i += 1
            case "(": tokens.append(.lparen); i += 1
            case ")": tokens.append(.rparen); i += 1
            default:
                // Read a number literal (digits and a single dot).
                guard ch.isNumber || ch == "." else { return [] }
                var literal = String(ch)
                i += 1
                while i < chars.count, chars[i].isNumber || chars[i] == "." {
                    literal.append(chars[i])
                    i += 1
                }
                // Tolerate a leading dot like ".5" by normalising to "0.5".
                if literal.hasPrefix(".") { literal = "0" + literal }
                guard let value = Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX")) else {
                    return []
                }
                tokens.append(.number(value))
            }
        }

        return tokens
    }
}

private struct Parser {
    let tokens: [Token]
    var index = 0

    var isAtEnd: Bool { index == tokens.count }

    private mutating func current() -> Token? {
        index < tokens.count ? tokens[index] : nil
    }

    /// Consumes the current token and advances to the next.
    private mutating func advance() {
        index += 1
    }

    /// expression = term (('+' | '-') term)*
    mutating func parseExpression() -> Decimal? {
        guard var left = parseTerm() else { return nil }
        while let token = current() {
            switch token {
            case .plus:
                advance()
                guard let right = parseTerm() else { return nil }
                left += right
            case .minus:
                advance()
                guard let right = parseTerm() else { return nil }
                left -= right
            default:
                return left
            }
        }
        return left
    }

    /// term = factor (('*' | '/') factor)*
    private mutating func parseTerm() -> Decimal? {
        guard var left = parseFactor() else { return nil }
        while let token = current() {
            switch token {
            case .times:
                advance()
                guard let right = parseFactor() else { return nil }
                left *= right
            case .divide:
                advance()
                guard let right = parseFactor(), right != 0 else { return nil }
                left /= right
            default:
                return left
            }
        }
        return left
    }

    /// factor = number | '(' expression ')' | ('+' | '-') factor
    private mutating func parseFactor() -> Decimal? {
        switch current() {
        case .number(let value):
            advance()
            return value
        case .lparen:
            advance()
            guard let value = parseExpression() else { return nil }
            guard case .rparen = current() else { return nil }
            advance()
            return value
        case .minus:
            advance()
            guard let value = parseFactor() else { return nil }
            return -value
        case .plus:
            advance()
            return parseFactor()
        default:
            return nil
        }
    }
}

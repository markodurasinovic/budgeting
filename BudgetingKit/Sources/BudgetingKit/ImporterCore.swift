import Foundation
import SwiftData

/// Shared logic for the CSV and XLSX importers.
///
/// Both file formats produce the same logical rows — a date, an item name, a
/// price, and an optional income column — and classify them the same way: as a
/// budget field (income/savings/investment/bills), a skip row (totals/
/// remainders), a bare category, a known shop name, or a regular tagged entry.
/// This enum holds that shared classification, parsing, and budget-application
/// logic so it lives in exactly one place.
///
/// The two importers differ only in how they turn a file into rows of strings:
/// `CSVImporter` tokenizes CSV text, `XLSXImporter` reads worksheet cells via
/// CoreXLSX. Both feed those strings into `ImporterCore.applyRow`.
public enum ImporterCore {
    /// Item names (lowercased) that map to budget fields rather than entries.
    public static let budgetKeywords: Set<String> = [
        "income", "savings", "investment", "bills",
    ]

    /// Item names (lowercased) that are summary rows to skip entirely.
    public static let budgetSkipKeywords: Set<String> = [
        "total spending", "subtotal", "remainder", "misc", "i+s",
    ]

    /// Known category names (lowercased) used for bare-item detection. When an
    /// item with no parenthetical tag matches one of these, the item itself
    /// becomes the tag. Merged with dynamic categories discovered in column E.
    public static let categoryKeywords: Set<String> = [
        "pub", "takeaway", "eating out", "groceries", "entertainment",
        "clothes", "train", "uber", "sport", "coffee",
        "holiday", "shopping",
    ]

    /// Shop names (lowercased) that map to the "Shopping" tag when the item has
    /// no explicit parenthetical tag.
    public static let shoppingNames: Set<String> = [
        "sainsburys", "lidl", "coop", "waitrose", "tesco", "m&s", "aldi",
    ]

    // MARK: - Parsing

    /// Parses a money string (`"£12.50"`, `"1,250"`, `"3.75"`) into a `Decimal`.
    /// Returns `nil` for empty or invalid input.
    public static func parseAmount(_ input: String) -> Decimal? {
        let cleaned = input
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US"))
    }

    /// Parses a date string in several common formats. When
    /// `supportsExcelSerial` is true, a bare number is read as an Excel serial
    /// date (days since Dec 30, 1899) — used for XLSX cells that store dates as
    /// numbers. CSV parsing leaves this off so numeric strings aren't mistaken
    /// for serials.
    public static func parseDate(_ input: String, supportsExcelSerial: Bool = false) -> Date? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        if supportsExcelSerial, let serial = Double(trimmed) {
            let excelEpoch = Date(timeIntervalSince1970: -2209161600) // Dec 30, 1899
            return excelEpoch.addingTimeInterval(serial * 86400)
        }

        for format in ["M/d/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "M/d/yy"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    /// Splits `"Item (Tag)"` into `("Item", "Tag")`. Returns the original string
    /// with a nil tag when there are no parentheses.
    public static func parseItemAndTag(_ raw: String) -> (item: String, tag: String?) {
        guard let openParen = raw.lastIndex(of: "("),
              let closeParen = raw.lastIndex(of: ")"),
              openParen < closeParen else {
            return (raw, nil)
        }

        let tagContent = raw[raw.index(after: openParen)..<closeParen].trimmingCharacters(in: .whitespaces)
        guard !tagContent.isEmpty else {
            return (raw, nil)
        }

        let itemName = raw[raw.startIndex..<openParen].trimmingCharacters(in: .whitespaces)
        return (itemName, tagContent)
    }

    // MARK: - Row application

    /// Classifies and applies a single item/price row, mutating `accumulator`
    /// to track imported/skipped counts, budget state, and skipped-row messages.
    ///
    /// `rowLabel` (e.g. a sheet name) is prefixed onto skipped-row messages so
    /// multi-sheet XLSX imports remain traceable; pass `""` for CSV.
    public static func applyRow(
        rawItemText: String,
        priceText: String,
        date: Date,
        allCategories: Set<String>,
        context: ModelContext,
        accumulator: inout ImportAccumulator,
        rowLabel: String
    ) {
        let itemText = rawItemText.trimmingCharacters(in: .whitespaces)
        let price = priceText.trimmingCharacters(in: .whitespaces)
        guard !itemText.isEmpty, !price.isEmpty else { return }

        let lowerRaw = itemText.lowercased()
        var (parsedItem, parenTag) = parseItemAndTag(itemText)
        let lowerParsed = parsedItem.lowercased()

        // If the item name is itself a known category and carries a parenthetical
        // tag, swap them: "Train (tfl)" -> item="Tfl", tag="Train".
        if allCategories.contains(lowerParsed), parenTag != nil {
            parsedItem = parenTag!
            parenTag = lowerParsed.capitalized
        }

        let lowerFinalItem = parsedItem.lowercased()
        let prefix = rowLabel.isEmpty ? "" : "[\(rowLabel)] "

        if budgetKeywords.contains(lowerRaw) {
            if let amount = parseAmount(price) {
                let month = Calendar.current.component(.month, from: date)
                let year = Calendar.current.component(.year, from: date)
                let budget = accumulator.ensureBudget(month: month, year: year, context: context)
                applyBudgetKeyword(lowerRaw, amount: amount, to: budget, budgetKey: "\(year)-\(month)", fieldsSet: &accumulator.budgetFieldsSet)
            }
            accumulator.skippedRows.append("\(prefix)Budget: \(itemText) — \(price)")
        } else if budgetSkipKeywords.contains(lowerRaw) {
            accumulator.skipped += 1
            accumulator.skippedRows.append("\(prefix)Skipped: \(itemText) — \(price)")
        } else if allCategories.contains(lowerFinalItem), parenTag == nil {
            if let amount = parseAmount(price) {
                BudgetStore.addEntry(date: date, item: parsedItem, tag: lowerFinalItem.capitalized, amount: amount, context: context)
                accumulator.imported += 1
            }
        } else if shoppingNames.contains(lowerFinalItem), parenTag == nil {
            if let amount = parseAmount(price) {
                BudgetStore.addEntry(date: date, item: parsedItem, tag: "Shopping", amount: amount, context: context)
                accumulator.imported += 1
            }
        } else {
            if let amount = parseAmount(price) {
                BudgetStore.addEntry(date: date, item: parsedItem, tag: parenTag, amount: amount, context: context)
                accumulator.imported += 1
            }
        }
    }

    /// Applies the income column (columns H/I or 7/8) when the item is "income".
    /// Other budget fields come from the main item/price columns; only income is
    /// read from this side column.
    public static func applyIncomeRow(
        incomeItem: String,
        incomePrice: String,
        date: Date,
        context: ModelContext,
        accumulator: inout ImportAccumulator
    ) {
        let item = incomeItem.trimmingCharacters(in: .whitespaces)
        let price = incomePrice.trimmingCharacters(in: .whitespaces)
        guard !item.isEmpty, !price.isEmpty, item.lowercased() == "income" else { return }
        guard let amount = parseAmount(price) else { return }

        let month = Calendar.current.component(.month, from: date)
        let year = Calendar.current.component(.year, from: date)
        let budget = accumulator.ensureBudget(month: month, year: year, context: context)
        applyBudgetKeyword("income", amount: amount, to: budget, budgetKey: "\(year)-\(month)", fieldsSet: &accumulator.budgetFieldsSet)
    }

    /// Applies a budget keyword to `budget` at most once per month. The
    /// `fieldsSet` dictionary tracks which keywords have already been set for
    /// each `budgetKey` (`"year-month"`) so duplicate rows in the source file
    /// don't overwrite the first value.
    public static func applyBudgetKeyword(
        _ keyword: String,
        amount: Decimal,
        to budget: MonthlyBudget,
        budgetKey: String,
        fieldsSet: inout [String: Set<String>]
    ) {
        guard var set = fieldsSet[budgetKey] else { return }
        guard !set.contains(keyword) else { return }
        set.insert(keyword)
        fieldsSet[budgetKey] = set

        switch keyword {
        case "income": budget.income = amount
        case "savings": budget.savings = amount
        case "investment": budget.investment = amount
        case "bills": budget.bills = amount
        default: break
        }
    }

    /// Lowercases and de-blanks a list of column values, for merging with
    /// `categoryKeywords` to build the dynamic category set.
    public static func collectDynamicCategories(_ values: [String]) -> Set<String> {
        Set(values.compactMap { $0.trimmingCharacters(in: .whitespaces).lowercased().nilIfEmpty })
    }
}

/// Mutable totals and per-month budget state accumulated while importing a file.
///
/// Passed `inout` into `ImporterCore.applyRow` so each row can update the
/// running counts. `budgetMonths` is derived from `processedBudgets` so it stays
/// consistent with the budgets actually touched.
public struct ImportAccumulator {
    public var imported = 0
    public var skipped = 0
    public var skippedRows: [String] = []
    public var sheetNames: [String] = []
    public var processedBudgets: [String: MonthlyBudget] = [:]
    public var budgetFieldsSet: [String: Set<String>] = [:]

    public init() {}

    /// Number of distinct months that had a budget created or updated.
    public var budgetMonths: Int { processedBudgets.count }

    /// Returns the budget for `(month, year)`, creating an empty one (and
    /// registering it in `budgetFieldsSet`) on first access. Ensures every month
    /// with a dated row contributes to `budgetMonths`, matching the original
    /// importers' behaviour. `@discardableResult` so callers that only need the
    /// side-effect (the row loop) can ignore the returned budget.
    @discardableResult
    public mutating func ensureBudget(month: Int, year: Int, context: ModelContext) -> MonthlyBudget {
        let key = "\(year)-\(month)"
        if let existing = processedBudgets[key] { return existing }
        let budget = BudgetStore.budgetForMonth(month, year: year, context: context)
        processedBudgets[key] = budget
        budgetFieldsSet[key] = []
        return budget
    }

    /// Builds the final result after all rows have been processed.
    public func result(errors: [String] = []) -> ImportResult {
        ImportResult(
            imported: imported,
            skipped: skipped,
            budgetMonths: budgetMonths,
            errors: errors,
            skippedRows: skippedRows,
            sheetNames: sheetNames
        )
    }
}

/// Outcome of an import, shared by `CSVImporter` and `XLSXImporter`. `sheetNames`
/// is empty for CSV; for XLSX it lists every worksheet processed.
public struct ImportResult {
    public let imported: Int
    public let skipped: Int
    public let budgetMonths: Int
    public let errors: [String]
    public let skippedRows: [String]
    public let sheetNames: [String]

    public init(
        imported: Int,
        skipped: Int,
        budgetMonths: Int,
        errors: [String],
        skippedRows: [String] = [],
        sheetNames: [String] = []
    ) {
        self.imported = imported
        self.skipped = skipped
        self.budgetMonths = budgetMonths
        self.errors = errors
        self.skippedRows = skippedRows
        self.sheetNames = sheetNames
    }
}

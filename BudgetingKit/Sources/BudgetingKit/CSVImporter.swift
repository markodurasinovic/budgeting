import Foundation
import SwiftData

public enum CSVImporter {
    public struct ImportResult {
        public let imported: Int
        public let skipped: Int
        public let budgetMonths: Int
        public let errors: [String]
        public let skippedRows: [String]

        public init(imported: Int, skipped: Int, budgetMonths: Int, errors: [String], skippedRows: [String] = []) {
            self.imported = imported
            self.skipped = skipped
            self.budgetMonths = budgetMonths
            self.errors = errors
            self.skippedRows = skippedRows
        }
    }

    private static let budgetKeywords: Set<String> = [
        "income", "savings", "investment", "bills"
    ]

    private static let budgetSkipKeywords: Set<String> = [
        "total spending", "subtotal", "remainder", "misc", "i+s"
    ]

    private static let categoryKeywords: Set<String> = [
        "pub", "takeaway", "eating out", "groceries", "entertainment",
        "clothes", "train", "uber", "sport", "coffee",
        "holiday", "shopping"
    ]

    private static let shoppingNames: Set<String> = [
        "sainsburys", "lidl", "coop", "waitrose", "tesco", "m&s", "aldi"
    ]

    public static func parse(content: String) -> (rows: [[String]], errors: [String]) {
        var rows: [[String]] = []
        var errors: [String] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let chars = Array(normalized)
        var i = 0

        while i < chars.count {
            let ch = chars[i]

            if inQuotes {
                if ch == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(ch)
                    i += 1
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                    i += 1
                } else if ch == "," {
                    currentRow.append(currentField)
                    currentField = ""
                    i += 1
                } else if ch == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.isEmpty {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    i += 1
                } else {
                    currentField.append(ch)
                    i += 1
                }
            }
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return (rows, errors)
    }

    public static func importEntries(from content: String, context: ModelContext) -> ImportResult {
        let (rows, _) = parse(content: content)
        var imported = 0
        var skipped = 0
        var errors: [String] = []
        var skippedRows: [String] = []
        var processedBudgets: [String: MonthlyBudget] = [:]
        var budgetFieldsSet: [String: Set<String>] = [:]

        guard rows.count > 1 else {
            return ImportResult(imported: 0, skipped: 0, budgetMonths: 0, errors: ["File is empty or has no data rows"])
        }

        // First pass: collect category names from column E (index 4) across all rows
        var dynamicCategories: Set<String> = []
        for rowIndex in 1..<rows.count {
            let row = rows[rowIndex]
            let col4 = safeCol(row, 4).trimmingCharacters(in: .whitespaces)
            if !col4.isEmpty {
                dynamicCategories.insert(col4.lowercased())
            }
        }
        let allCategories = categoryKeywords.union(dynamicCategories)

        for rowIndex in 1..<rows.count {
            let row = rows[rowIndex]
            guard row.count >= 3 else { continue }

            let dateStr = row[0].trimmingCharacters(in: .whitespaces)
            guard let date = parseDate(dateStr) else { continue }
            let month = Calendar.current.component(.month, from: date)
            let year = Calendar.current.component(.year, from: date)
            let budgetKey = "\(year)-\(month)"

            if processedBudgets[budgetKey] == nil {
                processedBudgets[budgetKey] = BudgetStore.budgetForMonth(month, year: year, context: context)
                budgetFieldsSet[budgetKey] = []
            }

            // Columns 0-2: Date, Item, Price
            let item01 = safeCol(row, 1).trimmingCharacters(in: .whitespaces)
            let price02 = safeCol(row, 2).trimmingCharacters(in: .whitespaces)
            if !item01.isEmpty && !price02.isEmpty {
                let lower01 = item01.lowercased()
                var (parsedItem, parenTag) = parseItemAndTag(item01)
                let lowerParsed = parsedItem.lowercased()

                // If item name is a known category and there's a parenthetical tag, swap them
                // e.g. "Train (tfl)" -> item="Tfl", tag="Train"
                if allCategories.contains(lowerParsed) && parenTag != nil {
                    parsedItem = parenTag!
                    parenTag = lowerParsed.capitalized
                }

                let lowerFinalItem = parsedItem.lowercased()

                if budgetKeywords.contains(lower01) {
                    // Budget keyword — apply to budget, don't create entry
                    if let amount = parseAmount(price02), let budget = processedBudgets[budgetKey] {
                        applyBudgetKeywordOnce(lower01, amount: amount, to: budget, budgetKey: budgetKey, fieldsSet: &budgetFieldsSet)
                    }
                    skippedRows.append("Budget: \(item01) — \(price02)")
                } else if budgetSkipKeywords.contains(lower01) {
                    skipped += 1
                    skippedRows.append("Skipped: \(item01) — \(price02)")
                } else if allCategories.contains(lowerFinalItem) && parenTag == nil {
                    // Bare category name without parens — treat as tagged entry
                    if let amount = parseAmount(price02) {
                        BudgetStore.addEntry(date: date, item: parsedItem, tag: lowerFinalItem.capitalized, amount: amount, context: context)
                        imported += 1
                    }
                } else if shoppingNames.contains(lowerFinalItem) && parenTag == nil {
                    if let amount = parseAmount(price02) {
                        BudgetStore.addEntry(date: date, item: parsedItem, tag: "Shopping", amount: amount, context: context)
                        imported += 1
                    }
                } else {
                    if let amount = parseAmount(price02) {
                        BudgetStore.addEntry(date: date, item: parsedItem, tag: parenTag, amount: amount, context: context)
                        imported += 1
                    }
                }
            }

            // Columns 4-5: Category totals — SKIP entirely

            // Columns 7-8: Only Income (other budget fields come from col 0-2)
            let item07 = safeCol(row, 7).trimmingCharacters(in: .whitespaces)
            let price08 = safeCol(row, 8).trimmingCharacters(in: .whitespaces)
            if !item07.isEmpty && !price08.isEmpty {
                let lower07 = item07.lowercased()
                if lower07 == "income" {
                    if let amount = parseAmount(price08), let budget = processedBudgets[budgetKey] {
                        applyBudgetKeywordOnce(lower07, amount: amount, to: budget, budgetKey: budgetKey, fieldsSet: &budgetFieldsSet)
                    }
                }
            }
        }

        let budgetMonths = processedBudgets.count

        return ImportResult(imported: imported, skipped: skipped, budgetMonths: budgetMonths, errors: errors, skippedRows: skippedRows)
    }

    private static func applyBudgetKeywordOnce(_ keyword: String, amount: Decimal, to budget: MonthlyBudget, budgetKey: String, fieldsSet: inout [String: Set<String>]) {
        guard var set = fieldsSet[budgetKey] else { return }
        guard !set.contains(keyword) else { return }
        set.insert(keyword)
        fieldsSet[budgetKey] = set

        switch keyword {
        case "income":
            budget.income = amount
        case "savings":
            budget.savings = amount
        case "investment":
            budget.investment = amount
        case "bills":
            budget.bills = amount
        default:
            break
        }
    }

    private static func applyBudgetKeyword(_ keyword: String, amount: Decimal, to budget: MonthlyBudget) {
        switch keyword {
        case "income":
            budget.income = amount
        case "savings":
            budget.savings = amount
        case "investment":
            budget.investment = amount
        case "bills":
            budget.bills = amount
        default:
            break
        }
    }

    private static func safeCol(_ row: [String], _ index: Int) -> String {
        guard index < row.count else { return "" }
        return row[index]
    }

    private static func parseDate(_ input: String) -> Date? {
        let format1 = { (str: String) -> Date? in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "M/d/yyyy"
            return formatter.date(from: str)
        }

        let format2 = { (str: String) -> Date? in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.date(from: str)
        }

        let format3 = { (str: String) -> Date? in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: str)
        }

        return format1(input) ?? format2(input) ?? format3(input)
    }

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

    private static func parseAmount(_ input: String) -> Decimal? {
        let cleaned = input
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: ",", with: "")

        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US"))
    }
}
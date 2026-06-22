import Foundation
import SwiftData

/// Imports entries and budget fields from CSV text.
///
/// The CSV format expected is: `Date, Item, Price, …, CategoryLabel, …, Income,
/// IncomePrice`. Item names may carry a parenthetical tag (`"Coffee (Food)"`).
/// The shared row-classification logic lives in `ImporterCore`; this file only
/// owns the CSV tokenizer that turns text into rows of strings.
public enum CSVImporter {
    /// Parses CSV text into rows of fields, honoring quoted fields and embedded
    /// commas/quotes. Handles `\n`, `\r\n`, and `\r` line endings. Empty trailing
    /// lines are dropped.
    public static func parse(content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let chars = Array(normalized)
        var i = 0

        while i < chars.count {
            let ch = chars[i]

            if inQuotes {
                if ch == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        // Escaped quote inside a quoted field.
                        currentField.append("\"")
                        i += 2
                    } else {
                        inQuotes = false
                        i += 1
                    }
                } else {
                    currentField.append(ch)
                    i += 1
                }
            } else {
                switch ch {
                case "\"":
                    inQuotes = true
                    i += 1
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                    i += 1
                case "\n":
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.isEmpty { rows.append(currentRow) }
                    currentRow = []
                    i += 1
                default:
                    currentField.append(ch)
                    i += 1
                }
            }
        }

        // Flush the final field/row if the file doesn't end with a newline.
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }

    /// Imports entries and budget fields from CSV `content` into `context`.
    /// Returns a summary of imported/skipped counts and any skipped rows.
    public static func importEntries(from content: String, context: ModelContext) -> ImportResult {
        let rows = parse(content: content)
        guard rows.count > 1 else {
            return ImportResult(imported: 0, skipped: 0, budgetMonths: 0, errors: ["File is empty or has no data rows"])
        }

        // First pass: collect dynamic category names from column E (index 4).
        let columnE = (1..<rows.count).map { safeCol(rows[$0], 4) }
        let allCategories = ImporterCore.categoryKeywords
            .union(ImporterCore.collectDynamicCategories(columnE))

        var accumulator = ImportAccumulator()

        for rowIndex in 1..<rows.count {
            let row = rows[rowIndex]
            guard row.count >= 3 else { continue }

            let dateStr = row[0].trimmingCharacters(in: .whitespaces)
            guard let date = ImporterCore.parseDate(dateStr) else { continue }
            let month = Calendar.current.component(.month, from: date)
            let year = Calendar.current.component(.year, from: date)
            accumulator.ensureBudget(month: month, year: year, context: context)

            // Columns 0-2: Date, Item, Price.
            ImporterCore.applyRow(
                rawItemText: safeCol(row, 1),
                priceText: safeCol(row, 2),
                date: date,
                allCategories: allCategories,
                context: context,
                accumulator: &accumulator,
                rowLabel: ""
            )

            // Columns 7-8: only Income is read here.
            ImporterCore.applyIncomeRow(
                incomeItem: safeCol(row, 7),
                incomePrice: safeCol(row, 8),
                date: date,
                context: context,
                accumulator: &accumulator
            )
        }

        return accumulator.result()
    }

    /// Safe column access: returns "" when `index` is beyond the row's width.
    private static func safeCol(_ row: [String], _ index: Int) -> String {
        row[safe: index] ?? ""
    }
}

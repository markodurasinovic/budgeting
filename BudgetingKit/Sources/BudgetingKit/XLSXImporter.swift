import Foundation
import SwiftData
import CoreXLSX

public enum XLSXImporter {
    public struct ImportResult {
        public let imported: Int
        public let skipped: Int
        public let budgetMonths: Int
        public let errors: [String]
        public let skippedRows: [String]
        public let sheetNames: [String]

        public init(imported: Int, skipped: Int, budgetMonths: Int, errors: [String], skippedRows: [String] = [], sheetNames: [String] = []) {
            self.imported = imported
            self.skipped = skipped
            self.budgetMonths = budgetMonths
            self.errors = errors
            self.skippedRows = skippedRows
            self.sheetNames = sheetNames
        }
    }

    public static func importEntries(from data: Data, context: ModelContext) -> ImportResult {
        let file: XLSXFile
        do {
            file = try XLSXFile(data: data)
        } catch {
            return ImportResult(imported: 0, skipped: 0, budgetMonths: 0, errors: ["Failed to open XLSX: \(error.localizedDescription)"], skippedRows: [])
        }

        var totalImported = 0
        var totalSkipped = 0
        var totalBudgetMonths = 0
        var allErrors: [String] = []
        var allSkippedRows: [String] = []
        var sheetNames: [String] = []
        var processedBudgets: [String: MonthlyBudget] = [:]
        var budgetFieldsSet: [String: Set<String>] = [:]

        let categoryKeywords: Set<String> = [
            "pub", "takeaway", "eating out", "groceries", "entertainment",
            "clothes", "train", "uber", "sport", "coffee",
            "holiday", "shopping"
        ]
        let budgetKeywords: Set<String> = ["income", "savings", "investment", "bills"]
        let budgetSkipKeywords: Set<String> = ["total spending", "subtotal", "remainder", "misc", "i+s"]
        let shoppingNames: Set<String> = ["sainsburys", "lidl", "coop", "waitrose", "tesco", "m&s", "aldi"]

        do {
            let wbk = try file.parseWorkbooks().first!
            let paths = try file.parseWorksheetPathsAndNames(workbook: wbk)
            let sharedStrings: SharedStrings = try! file.parseSharedStrings()!

            for (name, path) in paths {
                let sheetLabel = name ?? path
                sheetNames.append(sheetLabel)

                let worksheet = try file.parseWorksheet(at: path)
                let rows = worksheet.data?.rows ?? []
                guard !rows.isEmpty else { continue }

                // Build column-name-to-cell mapping per row
                // First pass: collect dynamic categories from col E
                var dynamicCategories: Set<String> = []
                for row in rows {
                    if let cell = row.cells.first(where: { $0.reference.column.value == "E" }) {
                        if let val = cellStringValue(cell, sharedStrings: sharedStrings)?.trimmingCharacters(in: .whitespaces), !val.isEmpty {
                            dynamicCategories.insert(val.lowercased())
                        }
                    }
                }
                let allCategories = categoryKeywords.union(dynamicCategories)

                for row in rows {
                    let colA = cellInRow(row, column: "A")
                    let colB = cellInRow(row, column: "B")
                    let colC = cellInRow(row, column: "C")
                    let colH = cellInRow(row, column: "H")
                    let colI = cellInRow(row, column: "I")

                    let dateStr = colA.flatMap { cellStringValue($0, sharedStrings: sharedStrings) }?.trimmingCharacters(in: .whitespaces) ?? ""
                    guard !dateStr.isEmpty, let date = parseDate(dateStr) else { continue }
                    let month = Calendar.current.component(.month, from: date)
                    let year = Calendar.current.component(.year, from: date)
                    let budgetKey = "\(year)-\(month)"

                    if processedBudgets[budgetKey] == nil {
                        processedBudgets[budgetKey] = BudgetStore.budgetForMonth(month, year: year, context: context)
                        budgetFieldsSet[budgetKey] = []
                    }

                    // Columns A-C: Date, Item, Price
                    let itemText = colB.flatMap { cellStringValue($0, sharedStrings: sharedStrings) }?.trimmingCharacters(in: .whitespaces) ?? ""
                    let priceText = colC.flatMap { cellStringValue($0, sharedStrings: sharedStrings) } ?? ""

                    if !itemText.isEmpty && !priceText.isEmpty {
                        let lower01 = itemText.lowercased()
                        var (parsedItem, parenTag) = CSVImporter.parseItemAndTag(itemText)
                        let lowerParsed = parsedItem.lowercased()

                        if allCategories.contains(lowerParsed) && parenTag != nil {
                            parsedItem = parenTag!
                            parenTag = lowerParsed.capitalized
                        }

                        let lowerFinalItem = parsedItem.lowercased()
                        let priceAmount = parseAmount(priceText)

                        if budgetKeywords.contains(lower01) {
                            if let amount = priceAmount, let budget = processedBudgets[budgetKey] {
                                applyBudgetKeywordOnce(lower01, amount: amount, to: budget, budgetKey: budgetKey, fieldsSet: &budgetFieldsSet)
                            }
                            allSkippedRows.append("[\(sheetLabel)] Budget: \(itemText) — \(priceText)")
                        } else if budgetSkipKeywords.contains(lower01) {
                            totalSkipped += 1
                            allSkippedRows.append("[\(sheetLabel)] Skipped: \(itemText) — \(priceText)")
                        } else if allCategories.contains(lowerFinalItem) && parenTag == nil {
                            if let amount = priceAmount {
                                BudgetStore.addEntry(date: date, item: parsedItem, tag: lowerFinalItem.capitalized, amount: amount, context: context)
                                totalImported += 1
                            }
                        } else if shoppingNames.contains(lowerFinalItem) && parenTag == nil {
                            if let amount = priceAmount {
                                BudgetStore.addEntry(date: date, item: parsedItem, tag: "Shopping", amount: amount, context: context)
                                totalImported += 1
                            }
                        } else {
                            if let amount = priceAmount {
                                BudgetStore.addEntry(date: date, item: parsedItem, tag: parenTag, amount: amount, context: context)
                                totalImported += 1
                            }
                        }
                    }

                    // Columns H-I: Only Income
                    let incomeItem = colH.flatMap { cellStringValue($0, sharedStrings: sharedStrings) }?.trimmingCharacters(in: .whitespaces) ?? ""
                    let incomePrice = colI.flatMap { cellStringValue($0, sharedStrings: sharedStrings) } ?? ""

                    if !incomeItem.isEmpty && !incomePrice.isEmpty {
                        let lowerH = incomeItem.lowercased()
                        if lowerH == "income" {
                            if let amount = parseAmount(incomePrice), let budget = processedBudgets[budgetKey] {
                                applyBudgetKeywordOnce(lowerH, amount: amount, to: budget, budgetKey: budgetKey, fieldsSet: &budgetFieldsSet)
                            }
                        }
                    }
                }
            }
        } catch {
            return ImportResult(imported: 0, skipped: 0, budgetMonths: 0, errors: ["Failed to parse XLSX: \(error.localizedDescription)"], skippedRows: [])
        }

        totalBudgetMonths = processedBudgets.count

        return ImportResult(
            imported: totalImported,
            skipped: totalSkipped,
            budgetMonths: totalBudgetMonths,
            errors: allErrors,
            skippedRows: allSkippedRows,
            sheetNames: sheetNames
        )
    }

    private static func cellInRow(_ row: CoreXLSX.Row, column: String) -> Cell? {
        row.cells.first { $0.reference.column.value == column }
    }

    private static func cellStringValue(_ cell: Cell, sharedStrings: SharedStrings) -> String? {
        if let s = cell.stringValue(sharedStrings) {
            return s
        }
        if let v = cell.value {
            return v
        }
        return cell.inlineString?.text
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

    private static func parseAmount(_ input: String) -> Decimal? {
        let cleaned = input
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US"))
    }

    private static func parseDate(_ input: String) -> Date? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Excel serial date number (e.g. 46266 = Sep 1, 2026)
        if let serial = Double(trimmed) {
            let excelEpoch = Date(timeIntervalSince1970: -2209161600) // Dec 30, 1899
            return excelEpoch.addingTimeInterval(serial * 86400)
        }

        let formats = ["M/d/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "M/d/yy"]
        for fmt in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = fmt
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }
}
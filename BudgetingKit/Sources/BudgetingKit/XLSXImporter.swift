import Foundation
import SwiftData
import CoreXLSX

/// Imports entries and budget fields from XLSX (Excel) workbooks.
///
/// All sheets in a workbook are processed. The shared row-classification logic
/// lives in `ImporterCore`; this file only owns the CoreXLSX cell-reading code
/// that turns a worksheet into rows of strings.
public enum XLSXImporter {
    /// Imports entries and budget fields from XLSX `data` into `context`.
    /// Returns a summary including the names of every sheet processed.
    public static func importEntries(from data: Data, context: ModelContext) -> ImportResult {
        let file: XLSXFile
        do {
            file = try XLSXFile(data: data)
        } catch {
            return ImportResult(
                imported: 0, skipped: 0, budgetMonths: 0,
                errors: ["Failed to open XLSX: \(error.localizedDescription)"]
            )
        }

        var accumulator = ImportAccumulator()

        do {
            guard let workbook = try file.parseWorkbooks().first else {
                return ImportResult(
                    imported: 0, skipped: 0, budgetMonths: 0,
                    errors: ["Workbook not found in XLSX file"]
                )
            }
            let paths = try file.parseWorksheetPathsAndNames(workbook: workbook)
            let sharedStrings = try file.parseSharedStrings()

            for (name, path) in paths {
                let sheetLabel = name ?? path
                accumulator.sheetNames.append(sheetLabel)

                let worksheet = try file.parseWorksheet(at: path)
                let rows = worksheet.data?.rows ?? []
                guard !rows.isEmpty else { continue }

                // First pass: collect dynamic category names from column E.
                let columnE = rows.compactMap { row -> String? in
                    guard let cell = row.cells.first(where: { $0.reference.column.value == "E" }) else { return nil }
                    return cellStringValue(cell, sharedStrings: sharedStrings)
                }
                let allCategories = ImporterCore.categoryKeywords
                    .union(ImporterCore.collectDynamicCategories(columnE))

                for row in rows {
                    let dateStr = cellInRow(row, column: "A")
                        .flatMap { cellStringValue($0, sharedStrings: sharedStrings) }?
                        .trimmingCharacters(in: .whitespaces) ?? ""
                    guard let date = ImporterCore.parseDate(dateStr, supportsExcelSerial: true) else { continue }
                    let month = Calendar.current.component(.month, from: date)
                    let year = Calendar.current.component(.year, from: date)
                    accumulator.ensureBudget(month: month, year: year, context: context)

                    // Columns A-C: Date, Item, Price.
                    let itemText = cellInRow(row, column: "B")
                        .flatMap { cellStringValue($0, sharedStrings: sharedStrings) } ?? ""
                    let priceText = cellInRow(row, column: "C")
                        .flatMap { cellStringValue($0, sharedStrings: sharedStrings) } ?? ""
                    ImporterCore.applyRow(
                        rawItemText: itemText,
                        priceText: priceText,
                        date: date,
                        allCategories: allCategories,
                        context: context,
                        accumulator: &accumulator,
                        rowLabel: sheetLabel
                    )

                    // Columns H-I: only Income is read here.
                    let incomeItem = cellInRow(row, column: "H")
                        .flatMap { cellStringValue($0, sharedStrings: sharedStrings) } ?? ""
                    let incomePrice = cellInRow(row, column: "I")
                        .flatMap { cellStringValue($0, sharedStrings: sharedStrings) } ?? ""
                    ImporterCore.applyIncomeRow(
                        incomeItem: incomeItem,
                        incomePrice: incomePrice,
                        date: date,
                        context: context,
                        accumulator: &accumulator
                    )
                }
            }
        } catch {
            return ImportResult(
                imported: 0, skipped: 0, budgetMonths: 0,
                errors: ["Failed to parse XLSX: \(error.localizedDescription)"]
            )
        }

        return accumulator.result()
    }

    // MARK: - CoreXLSX cell helpers

    /// Returns the cell in `row` for `column` ("A", "B", …), if present.
    private static func cellInRow(_ row: CoreXLSX.Row, column: String) -> Cell? {
        row.cells.first { $0.reference.column.value == column }
    }

    /// Reads a cell's display string, trying shared strings, a direct value, and
    /// an inline string in turn.
    private static func cellStringValue(_ cell: Cell, sharedStrings: SharedStrings?) -> String? {
        if let sharedStrings, let s = cell.stringValue(sharedStrings) {
            return s
        }
        if let v = cell.value {
            return v
        }
        return cell.inlineString?.text
    }
}

import CoreXLSX
import Foundation

let url = URL(fileURLWithPath: "/Users/markodurasinovic/dev/budgeting/accounting.xlsx")
let data = try Data(contentsOf: url)
let file = try XLSXFile(data: data)
let wbk = try file.parseWorkbooks().first!
let paths = try file.parseWorksheetPathsAndNames(workbook: wbk)
let sharedStrings = try file.parseSharedStrings()!

print("Found \(paths.count) sheets:")
for (name, path) in paths {
    print("\nSheet: \(name ?? "unnamed") at \(path)")
    let ws = try file.parseWorksheet(at: path)
    let rows = ws.data?.rows ?? []
    print("Rows: \(rows.count)")
    for (i, row) in rows.prefix(8).enumerated() {
        var cells: [String] = []
        for col in ["A","B","C","D","E","F","G","H","I","J","K","L"] {
            if let cell = row.cells.first(where: { $0.reference.column.value == col }) {
                var val = cell.stringValue(sharedStrings) ?? cell.value ?? cell.inlineString?.text ?? ""
                val = String(val.prefix(25))
                cells.append("\(col):\(val)")
            }
        }
        print("  Row\(i) r\(row.reference): \(cells.joined(separator: " | "))")
    }
}
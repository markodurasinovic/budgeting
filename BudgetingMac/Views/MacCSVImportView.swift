import SwiftUI
import SwiftData
import BudgetingKit
import UniformTypeIdentifiers

extension UTType {
    static var xlsx: UTType {
        UTType(filenameExtension: "xlsx") ?? .data
    }
}

struct MacCSVImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var totalResult: CSVImporter.ImportResult?
    @State private var xlsxResult: XLSXImporter.ImportResult?
    @State private var isImporting = false
    @State private var showingResult = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Import")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Import from CSV or XLSX files.\nSelect one or multiple files at once.\n\nXLSX workbooks: all sheets are imported.\nCSV: Date, Item, Price columns expected.\nTags parsed from parentheses.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Choose Files") {
                    isImporting = true
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420, height: 320)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText, .xlsx],
            allowsMultipleSelection: true
        ) { outcome in
            handleFileImport(outcome)
        }
        .sheet(isPresented: $showingResult) {
            if let r = totalResult {
                MacImportResultView(
                    result: r,
                    skippedRows: r.skippedRows,
                    sheetNames: [],
                    onDone: { dismiss() }
                )
            } else if let xr = xlsxResult {
                MacImportResultView(
                    result: CSVImporter.ImportResult(imported: xr.imported, skipped: xr.skipped, budgetMonths: xr.budgetMonths, errors: xr.errors, skippedRows: xr.skippedRows),
                    skippedRows: xr.skippedRows,
                    sheetNames: xr.sheetNames,
                    onDone: { dismiss() }
                )
            }
        }
    }

    private func handleFileImport(_ outcome: Result<[URL], Error>) {
        switch outcome {
        case .success(let urls):
            var totalImported = 0
            var totalSkipped = 0
            var totalBudgetMonths = 0
            var allErrors: [String] = []
            var allSkippedRows: [String] = []
            var allSheetNames: [String] = []

            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    if url.pathExtension == "xlsx" {
                        let data = try Data(contentsOf: url)
                        let result = XLSXImporter.importEntries(from: data, context: modelContext)
                        totalImported += result.imported
                        totalSkipped += result.skipped
                        totalBudgetMonths += result.budgetMonths
                        allErrors.append(contentsOf: result.errors)
                        allSkippedRows.append(contentsOf: result.skippedRows)
                        allSheetNames.append(contentsOf: result.sheetNames)
                        xlsxResult = XLSXImporter.ImportResult(imported: totalImported, skipped: totalSkipped, budgetMonths: totalBudgetMonths, errors: allErrors, skippedRows: allSkippedRows, sheetNames: allSheetNames)
                    } else {
                        let content = try String(contentsOf: url, encoding: .utf8)
                        let result = CSVImporter.importEntries(from: content, context: modelContext)
                        totalImported += result.imported
                        totalSkipped += result.skipped
                        totalBudgetMonths += result.budgetMonths
                        allErrors.append(contentsOf: result.errors)
                        allSkippedRows.append(contentsOf: result.skippedRows)
                        totalResult = CSVImporter.ImportResult(imported: totalImported, skipped: totalSkipped, budgetMonths: totalBudgetMonths, errors: allErrors, skippedRows: allSkippedRows)
                    }
                } catch {
                    allErrors.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            showingResult = true

        case .failure(let error):
            totalResult = CSVImporter.ImportResult(imported: 0, skipped: 0, budgetMonths: 0, errors: [error.localizedDescription])
            showingResult = true
        }
    }
}

struct MacImportResultView: View {
    let result: CSVImporter.ImportResult
    let skippedRows: [String]
    let sheetNames: [String]
    let onDone: () -> Void

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Import Complete")
                .font(.headline)

            TabView(selection: $selectedTab) {
                summaryTab
                    .tabItem { Label("Summary", systemImage: "list.bullet") }
                    .tag(0)

                if !skippedRows.isEmpty {
                    skippedTab
                        .tabItem { Label("Skipped", systemImage: "exclamationmark.triangle") }
                        .tag(1)
                }

                if !result.errors.isEmpty {
                    errorsTab
                        .tabItem { Label("Errors", systemImage: "xmark.circle") }
                        .tag(2)
                }
            }

            HStack {
                Spacer()
                Button("Done") { onDone() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }

    private var summaryTab: some View {
        List {
            Section("Results") {
                HStack {
                    Text("Entries imported")
                    Spacer()
                    Text("\(result.imported)")
                        .foregroundStyle(.secondary)
                }
                if result.budgetMonths > 0 {
                    HStack {
                        Text("Budget months updated")
                        Spacer()
                        Text("\(result.budgetMonths)")
                            .foregroundStyle(.secondary)
                    }
                }
                if !sheetNames.isEmpty {
                    HStack {
                        Text("Sheets processed")
                        Spacer()
                        Text("\(sheetNames.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                if result.skipped > 0 {
                    HStack {
                        Text("Rows skipped")
                        Spacer()
                        Text("\(result.skipped)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var skippedTab: some View {
        List {
            Section("Skipped rows") {
                ForEach(skippedRows, id: \.self) { row in
                    Text(row)
                        .font(.caption)
                }
            }
        }
    }

    private var errorsTab: some View {
        List {
            Section("Errors") {
                ForEach(result.errors, id: \.self) { error in
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

#Preview {
    MacCSVImportView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
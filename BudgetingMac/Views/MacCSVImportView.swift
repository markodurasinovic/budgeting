import SwiftUI
import SwiftData
import BudgetingKit
import UniformTypeIdentifiers

/// Registers `.xlsx` as a `UTType` so `fileImporter` can accept it alongside CSV.
/// `UTType(filenameExtension:)` returns nil on systems without the type
/// registered, so we fall back to `.data`.
extension UTType {
    static var xlsx: UTType {
        UTType(filenameExtension: "xlsx") ?? .data
    }
}

/// The import sheet: lets the user pick one or more CSV/XLSX files and shows a
/// summary of what was imported (entries, budget months, sheets, skipped rows,
/// errors). All selected files are aggregated into a single result.
struct MacCSVImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var result: ImportResult?
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

                Button("Choose Files") { isImporting = true }
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
        ) { handleFileImport($0) }
        .sheet(isPresented: $showingResult) {
            if let result {
                MacImportResultView(result: result, onDone: { dismiss() })
            }
        }
    }

    /// Imports every selected URL, aggregating CSV and XLSX results into a
    /// single `ImportResult`. A single result state (instead of separate
    /// per-format states) keeps mixed CSV+XLSX selections consistent.
    private func handleFileImport(_ outcome: Result<[URL], Error>) {
        switch outcome {
        case .success(let urls):
            var imported = 0, skipped = 0, budgetMonths = 0
            var errors: [String] = []
            var skippedRows: [String] = []
            var sheetNames: [String] = []

            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    if url.pathExtension == "xlsx" {
                        let data = try Data(contentsOf: url)
                        let r = XLSXImporter.importEntries(from: data, context: modelContext)
                        imported += r.imported
                        skipped += r.skipped
                        budgetMonths += r.budgetMonths
                        errors.append(contentsOf: r.errors)
                        skippedRows.append(contentsOf: r.skippedRows)
                        sheetNames.append(contentsOf: r.sheetNames)
                    } else {
                        let content = try String(contentsOf: url, encoding: .utf8)
                        let r = CSVImporter.importEntries(from: content, context: modelContext)
                        imported += r.imported
                        skipped += r.skipped
                        budgetMonths += r.budgetMonths
                        errors.append(contentsOf: r.errors)
                        skippedRows.append(contentsOf: r.skippedRows)
                    }
                } catch {
                    errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            result = ImportResult(
                imported: imported, skipped: skipped, budgetMonths: budgetMonths,
                errors: errors, skippedRows: skippedRows, sheetNames: sheetNames
            )
            showingResult = true

        case .failure(let error):
            result = ImportResult(imported: 0, skipped: 0, budgetMonths: 0, errors: [error.localizedDescription])
            showingResult = true
        }
    }
}

/// The post-import summary, shown in a tabbed window: results counts, skipped
/// rows, and any errors.
struct MacImportResultView: View {
    let result: ImportResult
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

                if !result.skippedRows.isEmpty {
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
                    Text("\(result.imported)").foregroundStyle(.secondary)
                }
                if result.budgetMonths > 0 {
                    HStack {
                        Text("Budget months updated")
                        Spacer()
                        Text("\(result.budgetMonths)").foregroundStyle(.secondary)
                    }
                }
                if !result.sheetNames.isEmpty {
                    HStack {
                        Text("Sheets processed")
                        Spacer()
                        Text("\(result.sheetNames.count)").foregroundStyle(.secondary)
                    }
                }
                if result.skipped > 0 {
                    HStack {
                        Text("Rows skipped")
                        Spacer()
                        Text("\(result.skipped)").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var skippedTab: some View {
        List {
            Section("Skipped rows") {
                ForEach(result.skippedRows, id: \.self) { row in
                    Text(row).font(.caption)
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

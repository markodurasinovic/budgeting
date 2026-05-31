import SwiftUI
import SwiftData
import BudgetingKit

struct TagDetailView: View {
    let tagName: String
    let month: Int
    let year: Int

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BudgetViewModel?

    private var entries: [Entry] {
        (viewModel?.entriesForMonth(month, year: year) ?? [])
            .filter { $0.tag == tagName }
    }

    private var total: Decimal {
        entries.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(MoneyHelper.format(total))
                        .font(.headline)
                        .foregroundStyle(total < 0 ? .red : .primary)
                }
            }

            Section("Entries") {
                if entries.isEmpty {
                    Text("No entries for \(tagName) this month")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries, id: \.id) { entry in
                    EntryRowView(entry: entry)
                }
            }
        }
        .navigationTitle(tagName)
        .onAppear {
            if viewModel == nil {
                viewModel = BudgetViewModel(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TagDetailView(tagName: "Food", month: 5, year: 2026)
    }
    .modelContainer(BudgetingContainer.makePreviewContainer())
}
import SwiftUI
import SwiftData
import BudgetingKit

struct TagDetailView: View {
    let tagName: String
    let month: Int
    let year: Int

    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.item)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    private var tagEntries: [Entry] {
        BudgetStore.entriesForMonth(entries, month: month, year: year)
            .filter { $0.tag == tagName }
    }

    private var total: Decimal {
        tagEntries.reduce(Decimal(0)) { $0 + $1.amount }
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
                if tagEntries.isEmpty {
                    Text("No entries for \(tagName) this month")
                        .foregroundStyle(.secondary)
                }
                ForEach(tagEntries, id: \.id) { entry in
                    EntryRowView(entry: entry)
                }
            }
        }
        .navigationTitle(tagName)
    }
}

#Preview {
    NavigationStack {
        TagDetailView(tagName: "Food", month: 5, year: 2026)
    }
    .modelContainer(BudgetingContainer.makePreviewContainer())
}
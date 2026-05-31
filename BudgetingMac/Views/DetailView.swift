import SwiftUI
import SwiftData
import BudgetingKit

struct DetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.item)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    let month: Int
    let year: Int
    let selectedTag: String?
    let onAddEntry: () -> Void
    let onEditEntry: (Entry) -> Void

    @State private var searchText = ""
    @State private var selectedEntries: Set<Entry.ID> = []

    private var effectiveTag: String? {
        if let tag = selectedTag, tag != "___ALL___" { return tag }
        return nil
    }

    private var filteredEntries: [Entry] {
        let monthEntries = BudgetStore.entriesForMonth(entries, month: month, year: year)
        let tagged: [Entry]
        if let tag = effectiveTag {
            tagged = monthEntries.filter { $0.tag == tag }
        } else {
            tagged = monthEntries
        }
        return BudgetStore.searchEntries(tagged, query: searchText)
    }

    private var total: Decimal {
        filteredEntries.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if filteredEntries.isEmpty {
                emptyState
            } else {
                entryTable
            }
        }
        .searchable(text: $searchText, prompt: "Search entries")
        .navigationTitle(effectiveTag ?? "All Entries")
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(effectiveTag ?? "All Entries")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(MoneyHelper.format(total))
                    .font(.title3)
                    .foregroundStyle(total < 0 ? .red : .secondary)
            }
            Spacer()
            Button {
                onAddEntry()
            } label: {
                Label("Add Entry", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No entries",
            systemImage: "tray",
            description: Text("Add an entry to get started")
        )
    }

    private var entryTable: some View {
        Table(filteredEntries, selection: $selectedEntries) {
            TableColumn("Date") { entry in
                Text(entry.date.formatted(.dateTime.day().month(.abbreviated)))
            }
            .width(min: 80)

            TableColumn("Item") { entry in
                Text(entry.item)
            }

            TableColumn("Tag") { entry in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.hex(entry.tag, from: BudgetStore.tagColorHex(tags, for: entry.tag)))
                        .frame(width: 8, height: 8)
                    Text(entry.tag)
                }
            }

            TableColumn("Amount") { entry in
                Text(MoneyHelper.format(entry.amount))
                    .foregroundStyle(entry.amount < 0 ? .red : .primary)
            }
            .width(min: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: Entry.ID.self) { items in
            Button("Delete", systemImage: "trash") {
                deleteSelected(items)
            }
        }
        .onDeleteCommand {
            deleteSelected(selectedEntries)
        }
    }

    private func deleteSelected(_ ids: Set<Entry.ID>) {
        let toDelete = filteredEntries.filter { ids.contains($0.id) }
        BudgetStore.deleteEntries(toDelete, context: modelContext)
    }
}

#Preview {
    DetailView(month: 5, year: 2026, selectedTag: nil, onAddEntry: {}, onEditEntry: { _ in })
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
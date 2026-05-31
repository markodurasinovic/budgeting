import SwiftUI
import BudgetingKit

struct DetailView: View {
    let viewModel: BudgetViewModel?
    let month: Int
    let year: Int
    let selectedTag: String?
    let onAddEntry: () -> Void
    let onEditEntry: (Entry) -> Void

    @State private var searchText = ""

    private var total: Decimal {
        filteredEntries.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var filteredEntries: [Entry] {
        let monthEntries: [Entry]
        if let tag = selectedTag {
            monthEntries = viewModel?.entriesForMonth(month, year: year)
                .filter { $0.tag == tag } ?? []
        } else {
            monthEntries = viewModel?.entriesForMonth(month, year: year) ?? []
        }

        guard !searchText.isEmpty else { return monthEntries }
        let lower = searchText.lowercased()
        return monthEntries.filter {
            $0.item.lowercased().contains(lower) ||
            $0.tag.lowercased().contains(lower)
        }
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
        .navigationTitle(selectedTag ?? "All Entries")
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(selectedTag ?? "All Entries")
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
        Table(filteredEntries) {
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
                        .fill(Color.hex(entry.tag, from: viewModel?.tagColor(for: entry.tag)))
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
    }
}

#Preview {
    DetailView(viewModel: nil, month: 5, year: 2026, selectedTag: nil, onAddEntry: {}, onEditEntry: { _ in })
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
import SwiftUI
import SwiftData
import BudgetingKit

struct EntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.item)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    @State private var selectedMonth = Date()
    @State private var showingAddSheet = false
    @State private var entryToEdit: Entry?
    @State private var searchText = ""

    private var month: Int {
        Calendar.current.component(.month, from: selectedMonth)
    }

    private var year: Int {
        Calendar.current.component(.year, from: selectedMonth)
    }

    private var monthEntries: [Entry] {
        let filtered = BudgetStore.entriesForMonth(entries, month: month, year: year)
        guard !searchText.isEmpty else { return filtered }
        return BudgetStore.searchEntries(filtered, query: searchText)
    }

    var body: some View {
        NavigationStack {
            Group {
                if monthEntries.isEmpty {
                    ContentUnavailableView(
                        "No entries",
                        systemImage: "tray",
                        description: Text("Add an entry for \(selectedMonth.formatted(.dateTime.year().month(.wide)))")
                    )
                } else {
                    List {
                        ForEach(monthEntries, id: \.id) { entry in
                            EntryRowView(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    entryToEdit = entry
                                }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                if let entry = monthEntries[safe: index] {
                                    BudgetStore.deleteEntry(entry, context: modelContext)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search entries")
            .navigationTitle("Entries")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonthPicker(selection: $selectedMonth)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditEntryView(mode: .add)
            }
            .sheet(isPresented: Binding(
                get: { entryToEdit != nil },
                set: { if !$0 { entryToEdit = nil } }
            )) {
                if let entry = entryToEdit {
                    AddEditEntryView(mode: .edit(entry))
                }
            }
        }
    }
}

#Preview {
    EntryListView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
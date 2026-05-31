import SwiftUI
import SwiftData
import BudgetingKit

struct EntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BudgetViewModel?
    @State private var selectedMonth = Date()
    @State private var showingAddSheet = false
    @State private var entryToEdit: Entry?

    private var month: Int {
        Calendar.current.component(.month, from: selectedMonth)
    }

    private var year: Int {
        Calendar.current.component(.year, from: selectedMonth)
    }

    private var monthEntries: [Entry] {
        viewModel?.entriesForMonth(month, year: year) ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
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
                                        vm.deleteEntry(entry)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
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
            .sheet(item: $entryToEdit) { entry in
                AddEditEntryView(mode: .edit(entry))
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = BudgetViewModel(modelContext: modelContext)
            }
        }
        .onChange(of: selectedMonth) {
            viewModel?.fetchAll()
        }
    }
}

#Preview {
    EntryListView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
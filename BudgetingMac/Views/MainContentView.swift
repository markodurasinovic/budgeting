import SwiftUI
import SwiftData
import BudgetingKit

struct MainContentView: View {
    @State private var selectedMonth = Date()
    @State private var selectedTag: String?
    @State private var showingAddSheet = false
    @Binding var showingImport: Bool
    @State private var entryToEdit: Entry?

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedMonth: $selectedMonth,
                selectedTag: $selectedTag
            )
        } detail: {
            if selectedTag == "___CATEGORIES___" {
                MacCategoryBreakdownView(
                    month: Calendar.current.component(.month, from: selectedMonth),
                    year: Calendar.current.component(.year, from: selectedMonth)
                )
            } else {
                DetailView(
                    month: Calendar.current.component(.month, from: selectedMonth),
                    year: Calendar.current.component(.year, from: selectedMonth),
                    selectedTag: selectedTag,
                    onAddEntry: { showingAddSheet = true },
                    onEditEntry: { entry in
                        entryToEdit = entry
                    }
                )
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            MacAddEditEntryView(mode: .add)
        }
        .sheet(isPresented: Binding(
            get: { entryToEdit != nil },
            set: { if !$0 { entryToEdit = nil } }
        )) {
            if let entry = entryToEdit {
                MacAddEditEntryView(mode: .edit(entry))
            }
        }
        .sheet(isPresented: $showingImport) {
            MacCSVImportView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newEntry)) { _ in
            showingAddSheet = true
        }
    }
}

#Preview {
    MainContentView(showingImport: .constant(false))
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
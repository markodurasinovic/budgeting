import SwiftUI
import SwiftData
import BudgetingKit

struct MainContentView: View {
    @State private var selectedMonth = Date()
    @State private var selectedTag: String?
    @State private var showingAddSheet = false
    @State private var entryToEdit: Entry?

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedMonth: $selectedMonth,
                selectedTag: $selectedTag
            )
        } detail: {
            DetailView(
                month: Calendar.current.component(.month, from: selectedMonth),
                year: Calendar.current.component(.year, from: selectedMonth),
                selectedTag: selectedTag,
                onAddEntry: { showingAddSheet = true },
                onEditEntry: { entry in entryToEdit = entry }
            )
        }
        .sheet(isPresented: $showingAddSheet) {
            MacAddEditEntryView(mode: .add)
        }
        .sheet(item: $entryToEdit) { entry in
            MacAddEditEntryView(mode: .edit(entry))
        }
        .onReceive(NotificationCenter.default.publisher(for: .newEntry)) { _ in
            showingAddSheet = true
        }
    }
}

#Preview {
    MainContentView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
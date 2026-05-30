import SwiftUI
import SwiftData
import BudgetingKit

struct MainContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BudgetViewModel?
    @State private var selectedMonth = Date()
    @State private var selectedTag: String?
    @State private var showingAddSheet = false
    @State private var entryToEdit: Entry?

    private var month: Int {
        Calendar.current.component(.month, from: selectedMonth)
    }

    private var year: Int {
        Calendar.current.component(.year, from: selectedMonth)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: viewModel,
                selectedMonth: $selectedMonth,
                selectedTag: $selectedTag
            )
        } detail: {
            DetailView(
                viewModel: viewModel,
                month: month,
                year: year,
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
        .onAppear {
            if viewModel == nil {
                viewModel = BudgetViewModel(modelContext: modelContext)
            }
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
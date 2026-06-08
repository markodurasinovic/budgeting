import SwiftUI
import SwiftData
import BudgetingKit

struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct MainContentView: View {
    @State private var selectedMonth = Date()
    @State private var selectedTag: String?
    @State private var addEntryDate: Date?
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
            } else if selectedTag == "___PORTFOLIO___" {
                MacPortfolioView(
                    month: Calendar.current.component(.month, from: selectedMonth),
                    year: Calendar.current.component(.year, from: selectedMonth)
                )
            } else if selectedTag == "___DAILY___" {
                MacDailySpendView(
                    month: Calendar.current.component(.month, from: selectedMonth),
                    year: Calendar.current.component(.year, from: selectedMonth)
                )
            } else {
                DetailView(
                    month: Calendar.current.component(.month, from: selectedMonth),
                    year: Calendar.current.component(.year, from: selectedMonth),
                    selectedTag: selectedTag,
                    onAddEntry: { date in
                        addEntryDate = date
                    },
                    onEditEntry: { entry in
                        entryToEdit = entry
                    }
                )
            }
        }
        .sheet(item: Binding(
            get: { addEntryDate.map { IdentifiableDate(date: $0) } },
            set: { newValue in addEntryDate = newValue?.date }
        )) { _ in
            MacAddEditEntryView(mode: .add(initialDate: addEntryDate))
        }
        .sheet(item: $entryToEdit) { entry in
            MacAddEditEntryView(mode: .edit(entry))
        }
        .sheet(isPresented: $showingImport) {
            MacCSVImportView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newEntry)) { _ in
            addEntryDate = Date()
        }
    }
}

#Preview {
    MainContentView(showingImport: .constant(false))
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
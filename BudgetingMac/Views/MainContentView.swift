import SwiftUI
import SwiftData
import BudgetingKit

struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct MainContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMonth = Date()
    @State private var selectedTag: String?
    @State private var addEntryDate: Date?
    @Binding var showingImport: Bool
    @Binding var addEntryFromWidget: Bool
    @State private var entryToEdit: Entry?

    var body: some View {
        let components = Calendar.current.dateComponents([.month, .year], from: selectedMonth)
        let month = components.month ?? 0
        let year = components.year ?? 0
        return NavigationSplitView {
            SidebarView(
                selectedMonth: $selectedMonth,
                selectedTag: $selectedTag
            )
        } detail: {
            if selectedTag == "___CATEGORIES___" {
                MacCategoryBreakdownView(month: month, year: year)
            } else if selectedTag == "___PORTFOLIO___" {
                MacPortfolioView(month: month, year: year)
            } else if selectedTag == "___DAILY___" {
                MacDailySpendView(month: month, year: year)
            } else {
                DetailView(
                    month: month,
                    year: year,
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
                .onDisappear {
                    BudgetingContainer.scheduleWidgetRefresh(context: modelContext)
                }
        }
        .sheet(item: $entryToEdit) { entry in
            MacAddEditEntryView(mode: .edit(entry))
                .onDisappear {
                    BudgetingContainer.scheduleWidgetRefresh(context: modelContext)
                }
        }
        .sheet(isPresented: $showingImport) {
            MacCSVImportView()
                .onDisappear {
                    BudgetingContainer.scheduleWidgetRefresh(context: modelContext)
                }
        }
        .onAppear {
            BudgetingContainer.scheduleWidgetRefresh(context: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newEntry)) { _ in
            addEntryDate = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshWidgets)) { _ in
            BudgetingContainer.scheduleWidgetRefresh(context: modelContext)
        }
        .onChange(of: addEntryFromWidget) { _, newValue in
            if newValue {
                addEntryDate = Date()
                addEntryFromWidget = false
            }
        }
    }
}

#Preview {
    MainContentView(showingImport: .constant(false), addEntryFromWidget: .constant(false))
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
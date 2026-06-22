import SwiftUI
import SwiftData
import BudgetingKit
import WidgetKit

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
                .onDisappear {
                    BudgetingContainer.writeWidgetData(context: modelContext)
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
        .sheet(item: $entryToEdit) { entry in
            MacAddEditEntryView(mode: .edit(entry))
                .onDisappear {
                    BudgetingContainer.writeWidgetData(context: modelContext)
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
        .sheet(isPresented: $showingImport) {
            MacCSVImportView()
                .onDisappear {
                    BudgetingContainer.writeWidgetData(context: modelContext)
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
        .onAppear {
            BudgetingContainer.writeWidgetData(context: modelContext)
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newEntry)) { _ in
            addEntryDate = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshWidgets)) { _ in
            BudgetingContainer.writeWidgetData(context: modelContext)
            WidgetCenter.shared.reloadAllTimelines()
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
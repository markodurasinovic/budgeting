import SwiftUI
import SwiftData
import BudgetingKit
import WidgetKit

/// A `Date` boxed in an `Identifiable` wrapper so it can drive a `.sheet(item:)`.
/// SwiftUI's `sheet(item:)` requires an identifiable binding; this lets the
/// add-entry sheet be presented on demand with a specific starting date.
struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

/// The top-level window content: a `NavigationSplitView` with a sidebar
/// (month/tag navigation) and a detail area that swaps between the entries
/// table, category breakdown, portfolio, and daily-spend views.
///
/// Also owns the three modal sheets (add/edit entry, budget edit via DetailView,
/// CSV/XLSX import) and keeps the widget's shared data in sync by calling
/// `refreshWidgets()` whenever entries or budgets change.
struct MainContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMonth = Date()
    @State private var selection: SidebarSelection? = .allEntries
    @State private var addEntryDate: Date?
    @Binding var showingImport: Bool
    @Binding var addEntryFromWidget: Bool
    @State private var entryToEdit: Entry?

    private var month: Int { Calendar.current.component(.month, from: selectedMonth) }
    private var year: Int { Calendar.current.component(.year, from: selectedMonth) }

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedMonth: $selectedMonth, selection: $selection)
        } detail: {
            detailView
        }
        .sheet(item: Binding(
            get: { addEntryDate.map { IdentifiableDate(date: $0) } },
            set: { addEntryDate = $0?.date }
        )) { _ in
            MacAddEditEntryView(mode: .add(initialDate: addEntryDate))
                .onDisappear(perform: refreshWidgets)
        }
        .sheet(item: $entryToEdit) { entry in
            MacAddEditEntryView(mode: .edit(entry))
                .onDisappear(perform: refreshWidgets)
        }
        .sheet(isPresented: $showingImport) {
            MacCSVImportView()
                .onDisappear(perform: refreshWidgets)
        }
        .onAppear(perform: refreshWidgets)
        .onReceive(NotificationCenter.default.publisher(for: .newEntry)) { _ in
            addEntryDate = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshWidgets)) { _ in
            refreshWidgets()
        }
        .onChange(of: addEntryFromWidget) { _, newValue in
            if newValue {
                addEntryDate = Date()
                addEntryFromWidget = false
            }
        }
    }

    /// Routes the sidebar selection to the matching detail view. A tag
    /// selection or `.allEntries` shows the entries table; the other cases show
    /// their dedicated analytics views.
    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .categories:
            MacCategoryBreakdownView(month: month, year: year)
        case .portfolio:
            MacPortfolioView(month: month, year: year)
        case .dailySpend:
            MacDailySpendView(month: month, year: year)
        case .tag(let tagName):
            DetailView(month: month, year: year, selectedTag: tagName,
                       onAddEntry: { addEntryDate = $0 },
                       onEditEntry: { entryToEdit = $0 })
        case .allEntries, nil:
            DetailView(month: month, year: year, selectedTag: nil,
                       onAddEntry: { addEntryDate = $0 },
                       onEditEntry: { entryToEdit = $0 })
        }
    }

    /// Writes the current month's summary to the shared App Group UserDefaults
    /// and asks WidgetKit to refresh every widget timeline. Called after any
    /// change that could affect the widget's display.
    private func refreshWidgets() {
        WidgetData.write(context: modelContext)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    MainContentView(showingImport: .constant(false), addEntryFromWidget: .constant(false))
        .modelContainer(BudgetingContainer.makePreviewContainer())
}

import SwiftUI
import SwiftData
import BudgetingKit

struct MainTabView: View {
    @State private var showingImport = false

    var body: some View {
        TabView {
            MonthlyOverviewView()
                .tabItem {
                    Label("Overview", systemImage: "chart.pie")
                }

            EntryListView()
                .tabItem {
                    Label("Entries", systemImage: "list.bullet")
                }

            TagSummaryView()
                .tabItem {
                    Label("Tags", systemImage: "tag")
                }

            CategoryBreakdownView()
                .tabItem {
                    Label("Categories", systemImage: "chart.bar.fill")
                }

            PortfolioView()
                .tabItem {
                    Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
        .sheet(isPresented: $showingImport) {
            CSVImportView()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingImport = true
                } label: {
                    Label("Import CSV", systemImage: "doc.text")
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
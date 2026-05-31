import SwiftUI
import SwiftData
import BudgetingKit

struct MainTabView: View {
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
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
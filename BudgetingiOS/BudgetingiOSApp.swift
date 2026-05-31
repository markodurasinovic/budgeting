import SwiftUI
import SwiftData
import BudgetingKit

@main
struct BudgetingiOSApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(BudgetingContainer.makeModelContainer())
        }
    }
}
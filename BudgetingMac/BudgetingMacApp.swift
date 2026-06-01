import SwiftUI
import SwiftData
import BudgetingKit

@main
struct BudgetingMacApp: App {
    @State private var showingImport = false

    var body: some Scene {
        WindowGroup {
            MainContentView(showingImport: $showingImport)
                .modelContainer(BudgetingContainer.makeModelContainer())
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandMenu("Entry") {
                Button("New Entry") {
                    NotificationCenter.default.post(name: .newEntry, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Import CSV") {
                    showingImport = true
                }
                .keyboardShortcut("i", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let newEntry = Notification.Name("newEntry")
}
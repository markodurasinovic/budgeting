import SwiftUI
import SwiftData
import BudgetingKit
import WidgetKit

@main
struct BudgetingMacApp: App {
    @State private var showingImport = false
    @State private var addEntryFromWidget = false

    var body: some Scene {
        WindowGroup {
            MainContentView(showingImport: $showingImport, addEntryFromWidget: $addEntryFromWidget)
                .modelContainer(BudgetingContainer.makeModelContainer())
                .onOpenURL { url in
                    handleURL(url)
                }
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

    private func handleURL(_ url: URL) {
        guard url.scheme == "budgeting" else { return }
        switch url.host {
        case "add-entry":
            addEntryFromWidget = true
        case "open":
            break
        default:
            break
        }
    }
}

extension Notification.Name {
    static let newEntry = Notification.Name("newEntry")
    static let refreshWidgets = Notification.Name("refreshWidgets")
}
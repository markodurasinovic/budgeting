import SwiftUI
import SwiftData
import BudgetingKit
import WidgetKit

/// The app's entry point. Declared with `@main` so the OS runs it on launch.
///
/// Sets up the `ModelContainer` (the SwiftData database connection), the main
/// `WindowGroup` hosting `MainContentView`, the menu-bar keyboard shortcuts,
/// and the deep-link handler that lets the widget's "Add Entry" button open the
/// add-entry sheet via the `budgeting://` URL scheme.
@main
struct BudgetingMacApp: App {
    @State private var showingImport = false
    @State private var addEntryFromWidget = false

    var body: some Scene {
        WindowGroup {
            MainContentView(showingImport: $showingImport, addEntryFromWidget: $addEntryFromWidget)
                .modelContainer(BudgetingContainer.makeModelContainer())
                .onOpenURL { handleURL($0) }
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

    /// Routes `budgeting://` deep links. `add-entry` (sent by the widget's
    /// "Add Entry" button) flips `addEntryFromWidget`, which `MainContentView`
    /// observes to present the add-entry sheet. `open` is a no-op landing link.
    private func handleURL(_ url: URL) {
        guard url.scheme == "budgeting" else { return }
        switch url.host {
        case "add-entry": addEntryFromWidget = true
        case "open":      break
        default:          break
        }
    }
}

/// `NotificationCenter` names used to communicate between the menu-bar commands
/// (which live in `BudgetingMacApp`) and the view layer (which can't see the
/// `@State` flags directly). A lightweight alternative to a shared model object.
extension Notification.Name {
    static let newEntry = Notification.Name("newEntry")
    static let refreshWidgets = Notification.Name("refreshWidgets")
}

import Foundation
import SwiftData

/// Entry point for creating the app's `ModelContainer` (the SwiftData database
/// connection) and a seedable in-memory container for SwiftUI previews.
public enum BudgetingContainer {
    /// The set of persisted model types. Declared once so the real container and
    /// the preview container stay in sync when models are added or removed.
    private static let schema = Schema([
        Entry.self,
        Tag.self,
        MonthlyBudget.self,
        PortfolioSnapshot.self,
        DebtSnapshot.self,
    ])

    /// Creates the on-disk `ModelContainer` used by the running app.
    ///
    /// On a corrupt-store error the existing `.sqlite`/`.sqlite-wal`/`.sqlite-shm`
    /// files are removed and a fresh container is created. This is a last-resort
    /// recovery so a bad database doesn't permanently block launch — but it does
    /// discard data, which is acceptable for this local-only app. If the rebuild
    /// also fails, `fatalError` reports the cause rather than crashing silently
    /// (the previous `try!` gave no diagnostic).
    ///
    /// `@MainActor` because `assignTagColors` touches the container's main
    /// context, which is main-actor-isolated.
    @MainActor
    public static func makeModelContainer() -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            BudgetStore.assignTagColors(in: container.mainContext)
            return container
        } catch {
            removeStoreFiles(at: config.url)
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                BudgetStore.assignTagColors(in: container.mainContext)
                return container
            } catch {
                fatalError("Could not create ModelContainer after wiping store at \(config.url): \(error)")
            }
        }
    }

    /// Creates an in-memory `ModelContainer` preloaded with sample tags, entries,
    /// and a budget for the current month. Used by `#Preview` blocks in views so
    /// Xcode canvas renders with realistic data.
    @MainActor
    public static func makePreviewContainer() -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])

        let context = container.mainContext
        context.insert(Tag(name: "Food", colorHex: "#FF6B35"))
        context.insert(Tag(name: "Rent", colorHex: "#4ECDC4"))
        context.insert(Tag(name: "Salary", colorHex: "#45B7D1"))

        let now = Date()
        context.insert(Entry(date: now, item: "Groceries", tag: "Food", amount: Decimal(string: "45.50")!))
        context.insert(Entry(date: now, item: "Monthly rent", tag: "Rent", amount: Decimal(string: "1250")!))
        context.insert(Entry(date: now, item: "Paycheck", tag: "Salary", amount: Decimal(string: "3500")!))
        context.insert(Entry(date: now.addingTimeInterval(-86400), item: "Coffee", tag: "Food", amount: Decimal(string: "3.75")!))

        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        context.insert(MonthlyBudget(
            month: month, year: year,
            income: Decimal(string: "3500")!,
            savings: Decimal(string: "500")!,
            investment: Decimal(string: "200")!
        ))

        return container
    }

    /// Removes the SQLite store files at `url` plus its `-wal` and `-shm`
    /// sidecars. Failures are ignored (best-effort cleanup before a rebuild).
    private static func removeStoreFiles(at url: URL) {
        let urls = [
            url,
            url.deletingPathExtension().appendingPathExtension("sqlite-wal"),
            url.deletingPathExtension().appendingPathExtension("sqlite-shm"),
        ]
        for fileURL in urls {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}

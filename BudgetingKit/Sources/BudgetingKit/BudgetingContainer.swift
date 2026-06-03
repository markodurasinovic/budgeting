import Foundation
import SwiftData

public enum BudgetingContainer {
    @MainActor
    public static func makeModelContainer() -> ModelContainer {
        let schema = Schema([Entry.self, Tag.self, MonthlyBudget.self, PortfolioSnapshot.self, DebtSnapshot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .none, cloudKitDatabase: .none)

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            BudgetStore.assignTagColors(in: container.mainContext)
            return container
        } catch {
            let url = config.url
            let dbUrls = [
                url,
                url.deletingPathExtension().appendingPathExtension("sqlite-wal"),
                url.deletingPathExtension().appendingPathExtension("sqlite-shm")
            ]
            for dbUrl in dbUrls {
                try? FileManager.default.removeItem(at: dbUrl)
            }
            let container = try! ModelContainer(for: schema, configurations: [config])
            BudgetStore.assignTagColors(in: container.mainContext)
            return container
        }
    }

    @MainActor
    public static func makePreviewContainer() -> ModelContainer {
        let schema = Schema([Entry.self, Tag.self, MonthlyBudget.self, PortfolioSnapshot.self, DebtSnapshot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])

        let context = container.mainContext
        let food = Tag(name: "Food", colorHex: "#FF6B35")
        let rent = Tag(name: "Rent", colorHex: "#4ECDC4")
        let salary = Tag(name: "Salary", colorHex: "#45B7D1")
        context.insert(food)
        context.insert(rent)
        context.insert(salary)

        let now = Date()
        context.insert(Entry(date: now, item: "Groceries", tag: "Food", amount: Decimal(string: "45.50")!))
        context.insert(Entry(date: now, item: "Monthly rent", tag: "Rent", amount: Decimal(string: "1250")!))
        context.insert(Entry(date: now, item: "Paycheck", tag: "Salary", amount: Decimal(string: "3500")!))
        context.insert(Entry(date: now.addingTimeInterval(-86400), item: "Coffee", tag: "Food", amount: Decimal(string: "3.75")!))

        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        let budget = MonthlyBudget(month: month, year: year, income: Decimal(string: "3500")!, savings: Decimal(string: "500")!, investment: Decimal(string: "200")!)
        context.insert(budget)

        return container
    }
}
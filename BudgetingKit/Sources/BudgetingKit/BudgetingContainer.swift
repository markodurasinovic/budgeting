import Foundation
import SwiftData

public enum BudgetingContainer {
    public static func makeModelContainer() -> ModelContainer {
        let schema = Schema([Entry.self, Tag.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    public static func makePreviewContainer() -> ModelContainer {
        let schema = Schema([Entry.self, Tag.self])
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

        return container
    }
}
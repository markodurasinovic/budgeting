import Foundation
import SwiftData

public enum BudgetingContainer {
    public static let appGroupIdentifier = "group.com.markodurasinovic.budgeting"

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

    public static func writeWidgetData(context: ModelContext) {
        let suiteDefaults = UserDefaults(suiteName: appGroupIdentifier)
        guard let defaults = suiteDefaults else { return }

        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        let budget = BudgetStore.budgetForMonth(month, year: year, context: context)

        let entryDescriptor = FetchDescriptor<Entry>()
        let allEntries = (try? context.fetch(entryDescriptor)) ?? []
        let monthEntries = BudgetStore.entriesForMonth(allEntries, month: month, year: year)
        let expenses = monthEntries.reduce(Decimal(0)) { $0 + $1.amount }

        let remainder = BudgetStore.remainder(
            income: budget.income,
            expenses: expenses,
            bills: budget.bills,
            savings: budget.savings,
            investment: budget.investment
        )

        let totalDays = BudgetStore.daysInMonth(month: month, year: year)
        let daysElapsed = BudgetStore.daysElapsedInMonth(month: month, year: year)
        let daysRemaining = BudgetStore.daysRemainingInMonth(month: month, year: year)
        let dailyBudget = daysRemaining > 0 ? remainder / Decimal(daysRemaining) : Decimal(0)

        let hasData = budget.income > 0 || !monthEntries.isEmpty

        defaults.set(NSDecimalNumber(decimal: remainder).doubleValue, forKey: "widget_remainder")
        defaults.set(NSDecimalNumber(decimal: dailyBudget).doubleValue, forKey: "widget_dailyBudget")
        defaults.set(NSDecimalNumber(decimal: budget.income).doubleValue, forKey: "widget_income")
        defaults.set(NSDecimalNumber(decimal: budget.bills).doubleValue, forKey: "widget_bills")
        defaults.set(NSDecimalNumber(decimal: expenses).doubleValue, forKey: "widget_expenses")
        defaults.set(NSDecimalNumber(decimal: budget.savings).doubleValue, forKey: "widget_savings")
        defaults.set(NSDecimalNumber(decimal: budget.investment).doubleValue, forKey: "widget_investment")
        defaults.set(daysRemaining, forKey: "widget_daysRemaining")
        defaults.set(daysElapsed, forKey: "widget_daysElapsed")
        defaults.set(totalDays, forKey: "widget_totalDays")
        defaults.set(hasData, forKey: "widget_hasData")
        defaults.set(month, forKey: "widget_month")
        defaults.set(year, forKey: "widget_year")
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
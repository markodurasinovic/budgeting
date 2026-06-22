import Foundation
import SwiftData

/// Shared bridge between the main app and the widget extension.
///
/// The app and widget run in separate processes, so they can't share a
/// `ModelContainer` directly. Instead, the app writes a small summary of the
/// current month's budget to an App Group `UserDefaults` (a shared key-value
/// store enabled by the App Groups entitlement), and the widget reads it on each
/// timeline refresh.
///
/// This enum owns the App Group identifier, the UserDefaults key strings, and
/// the read/write logic — so there's a single source of truth instead of the
/// key strings being duplicated in `BudgetingContainer` and the widget's
/// timeline provider.
public enum WidgetData {
    /// The App Group both targets share. Must match the entitlements on the app
    /// and widget targets. See `WIDGET_SETUP.md` for the manual Xcode step.
    public static let appGroupIdentifier = "group.com.markodurasinovic.budgeting"

    /// UserDefaults key strings for each field written by `write` and read by
    /// `read`. Scoped to an enum so the keys live next to the code that uses them
    /// and are checked at compile time (no typos in magic strings).
    public enum Key {
        public static let remainder = "widget_remainder"
        public static let dailyBudget = "widget_dailyBudget"
        public static let income = "widget_income"
        public static let bills = "widget_bills"
        public static let expenses = "widget_expenses"
        public static let savings = "widget_savings"
        public static let investment = "widget_investment"
        public static let daysRemaining = "widget_daysRemaining"
        public static let daysElapsed = "widget_daysElapsed"
        public static let totalDays = "widget_totalDays"
        public static let hasData = "widget_hasData"
        public static let month = "widget_month"
        public static let year = "widget_year"
    }

    /// A snapshot of the current month's budget, read back from UserDefaults.
    /// All numeric fields are `Double`/`Int` because `UserDefaults` doesn't store
    /// `Decimal` directly. The widget converts them to display strings.
    public struct Snapshot {
        public let remainder: Double
        public let dailyBudget: Double
        public let income: Double
        public let bills: Double
        public let expenses: Double
        public let savings: Double
        public let investment: Double
        public let daysRemaining: Int
        public let daysElapsed: Int
        public let totalDays: Int
        public let hasData: Bool
        public let month: Int
        public let year: Int
    }

    /// Computes the current month's summary from `context` and writes it to the
    /// shared UserDefaults. Safe to call on any thread; `UserDefaults` is
    /// thread-safe. Does nothing if the App Group is unavailable.
    public static func write(context: ModelContext) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

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
        let daysRemaining = max(totalDays - daysElapsed, 0)
        let dailyBudget = daysRemaining > 0 ? remainder / Decimal(daysRemaining) : Decimal(0)

        let hasData = budget.income > 0 || !monthEntries.isEmpty

        defaults.set(remainder.doubleValue, forKey: Key.remainder)
        defaults.set(dailyBudget.doubleValue, forKey: Key.dailyBudget)
        defaults.set(budget.income.doubleValue, forKey: Key.income)
        defaults.set(budget.bills.doubleValue, forKey: Key.bills)
        defaults.set(expenses.doubleValue, forKey: Key.expenses)
        defaults.set(budget.savings.doubleValue, forKey: Key.savings)
        defaults.set(budget.investment.doubleValue, forKey: Key.investment)
        defaults.set(daysRemaining, forKey: Key.daysRemaining)
        defaults.set(daysElapsed, forKey: Key.daysElapsed)
        defaults.set(totalDays, forKey: Key.totalDays)
        defaults.set(hasData, forKey: Key.hasData)
        defaults.set(month, forKey: Key.month)
        defaults.set(year, forKey: Key.year)
    }

    /// Reads the last written snapshot, or `nil` when no data has been written
    /// (or the App Group is unavailable). Used by the widget's timeline provider.
    public static func read() -> Snapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return nil }
        guard defaults.bool(forKey: Key.hasData) else { return nil }
        return Snapshot(
            remainder: defaults.double(forKey: Key.remainder),
            dailyBudget: defaults.double(forKey: Key.dailyBudget),
            income: defaults.double(forKey: Key.income),
            bills: defaults.double(forKey: Key.bills),
            expenses: defaults.double(forKey: Key.expenses),
            savings: defaults.double(forKey: Key.savings),
            investment: defaults.double(forKey: Key.investment),
            daysRemaining: defaults.integer(forKey: Key.daysRemaining),
            daysElapsed: defaults.integer(forKey: Key.daysElapsed),
            totalDays: defaults.integer(forKey: Key.totalDays),
            hasData: defaults.bool(forKey: Key.hasData),
            month: defaults.integer(forKey: Key.month),
            year: defaults.integer(forKey: Key.year)
        )
    }
}

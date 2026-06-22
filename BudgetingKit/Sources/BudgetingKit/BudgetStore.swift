import Foundation
import SwiftData

/// Stateless operations on the budgeting data model: entry CRUD, tag resolution,
/// month/calendar math, and derived budget metrics.
///
/// This is an `enum` used as a namespace — it has no cases, so it cannot be
/// instantiated. Putting free functions on an enum (instead of at file scope)
/// keeps them namespaced under `BudgetStore.` at call sites, which makes the
/// intent obvious: `BudgetStore.addEntry(...)`, `BudgetStore.remainder(...)`.
///
/// All functions take a `ModelContext` explicitly rather than reading a global,
/// so they're testable and work against any container (real or in-memory).
public enum BudgetStore {

    // MARK: - Entry CRUD

    /// Inserts a new `Entry`, resolving `tag` to a canonical name and creating a
    /// `Tag` record if needed. A nil/empty `tag` becomes `"Uncategorised"`.
    public static func addEntry(date: Date, item: String, tag: String?, amount: Decimal, context: ModelContext) {
        let resolvedTag = resolveTag(tag?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? "Uncategorised", context: context)
        let entry = Entry(date: date, item: item, tag: resolvedTag, amount: amount)
        context.insert(entry)
    }

    /// Updates an existing `Entry` in place. If the tag changed, the old tag is
    /// removed when no other entries reference it (see `removeOrphanTag`).
    public static func updateEntry(_ entry: Entry, date: Date, item: String, tag: String?, amount: Decimal, context: ModelContext) {
        let resolvedTag = resolveTag(tag?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? "Uncategorised", context: context)
        let oldTag = entry.tag
        entry.date = date
        entry.item = item
        entry.tag = resolvedTag
        entry.amount = amount
        if oldTag != resolvedTag {
            removeOrphanTag(named: oldTag, context: context)
        }
    }

    /// Deletes an `Entry` and removes its tag if no entries reference it.
    public static func deleteEntry(_ entry: Entry, context: ModelContext) {
        let tagName = entry.tag
        context.delete(entry)
        removeOrphanTag(named: tagName, context: context)
    }

    /// Deletes multiple `Entry`s in one pass, checking orphaned tags once each.
    public static func deleteEntries(_ entries: [Entry], context: ModelContext) {
        var tagsToCheck = Set<String>()
        for entry in entries {
            tagsToCheck.insert(entry.tag)
            context.delete(entry)
        }
        for tagName in tagsToCheck {
            removeOrphanTag(named: tagName, context: context)
        }
    }

    // MARK: - Tag colors

    /// Predicts the palette color for `tagName` given the current set of tags.
    ///
    /// `assignTagColors` (run at launch) assigns colors by sorting all tag names
    /// and mapping the sorted index onto `TagPalette`. This function reproduces
    /// that mapping so a freshly created tag gets the color it will keep after
    /// the next launch. When `tagName` isn't in `allTags` (a brand-new tag), a
    /// stable hash of the name picks a color so the result is deterministic
    /// across launches (unlike `String.hashValue`, which is randomized per run).
    public static func colorForTag(_ tagName: String, allTags: [Tag]) -> String {
        let sorted = allTags.map(\.name).sorted { $0.lowercased() < $1.lowercased() }
        if let index = sorted.firstIndex(where: { $0.lowercased() == tagName.lowercased() }) {
            return TagPalette.color(at: index)
        }
        return TagPalette.hex(for: tagName)
    }

    /// Returns the stored color hex for `tagName`, or a stable fallback when the
    /// tag has no color assigned yet.
    public static func tagColorHex(_ tags: [Tag], for tagName: String) -> String? {
        guard let tag = tags.first(where: { $0.name.lowercased() == tagName.lowercased() }) else {
            return nil
        }
        if !tag.colorHex.isEmpty {
            return tag.colorHex
        }
        return colorForTag(tagName, allTags: tags)
    }

    /// Reassigns colors to all tags by sorting names case-insensitively and
    /// mapping onto `TagPalette`. Called once at container creation so colors
    /// stay evenly distributed across the palette as tags are added.
    public static func assignTagColors(in context: ModelContext) {
        let descriptor = FetchDescriptor<Tag>()
        guard let tags = try? context.fetch(descriptor), !tags.isEmpty else { return }

        let sorted = tags.sorted { $0.name.lowercased() < $1.name.lowercased() }
        for (index, tag) in sorted.enumerated() {
            tag.colorHex = TagPalette.color(at: index)
        }
        try? context.save()
    }

    // MARK: - Month filtering and totals

    /// Filters `entries` to those falling in the given calendar `month` (1–12)
    /// and `year`, using the user's current calendar and time zone.
    public static func entriesForMonth(_ entries: [Entry], month: Int, year: Int) -> [Entry] {
        let calendar = Calendar.current
        return entries.filter { entry in
            let components = calendar.dateComponents([.month, .year], from: entry.date)
            return components.month == month && components.year == year
        }
    }

    /// Sum of `amount` across entries in the given month.
    public static func totalForMonth(_ entries: [Entry], month: Int, year: Int) -> Decimal {
        entriesForMonth(entries, month: month, year: year).reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Per-day totals for the given month, sorted by day 1..N, with `Decimal(0)`
    /// for days that have no entries. Useful for the daily-spend bar chart.
    public static func totalsByDayForMonth(_ entries: [Entry], month: Int, year: Int) -> [(day: Int, total: Decimal)] {
        let monthEntries = entriesForMonth(entries, month: month, year: year)
        let calendar = Calendar.current
        var totals: [Int: Decimal] = [:]
        for entry in monthEntries {
            let day = calendar.component(.day, from: entry.date)
            totals[day, default: Decimal(0)] += entry.amount
        }
        return (1...daysInMonth(month: month, year: year)).map { day in
            (day: day, total: totals[day] ?? Decimal(0))
        }
    }

    /// Per-tag totals for the given month, sorted by descending total (so the
    /// biggest spending categories appear first). Callers that need absolute-value
    /// sorting re-sort the result — see `DetailView.tagTotalsByAbs`.
    public static func totalsByTagForMonth(_ entries: [Entry], month: Int, year: Int) -> [(tag: String, total: Decimal)] {
        let monthEntries = entriesForMonth(entries, month: month, year: year)
        var totals: [String: Decimal] = [:]
        for entry in monthEntries {
            totals[entry.tag, default: Decimal(0)] += entry.amount
        }
        return totals.sorted { $0.value > $1.value }.map { (tag: $0.key, total: $0.value) }
    }

    /// Filters `entries` by a case-insensitive substring match on item or tag.
    /// An empty `query` returns all entries.
    public static func searchEntries(_ entries: [Entry], query: String) -> [Entry] {
        guard !query.isEmpty else { return entries }
        let lower = query.lowercased()
        return entries.filter {
            $0.item.lowercased().contains(lower) ||
            $0.tag.lowercased().contains(lower)
        }
    }

    // MARK: - Calendar math

    /// Number of days in the given calendar month. Defaults to `30` if the
    /// calendar can't compute the range (shouldn't happen for valid inputs).
    public static func daysInMonth(month: Int, year: Int) -> Int {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    /// Days elapsed in the given month. For the current month this is today's
    /// day-of-month; for past or future months it's the full `daysInMonth`.
    public static func daysElapsedInMonth(month: Int, year: Int) -> Int {
        let now = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        if month == currentMonth && year == currentYear {
            return calendar.component(.day, from: now)
        }
        return daysInMonth(month: month, year: year)
    }

    /// Average daily spend for the given month: `totalForMonth / daysElapsed`.
    /// Returns `0` when no days have elapsed.
    public static func averageDailySpend(_ entries: [Entry], month: Int, year: Int) -> Decimal {
        let daysElapsed = daysElapsedInMonth(month: month, year: year)
        guard daysElapsed > 0 else { return Decimal(0) }
        let total = totalForMonth(entries, month: month, year: year)
        return total / Decimal(daysElapsed)
    }

    /// Projects the month's total spend by extrapolating the daily average:
    /// `averageDailySpend * daysInMonth`. Useful mid-month for a forecast.
    public static func estimatedMonthlySpend(_ entries: [Entry], month: Int, year: Int) -> Decimal {
        let avg = averageDailySpend(entries, month: month, year: year)
        return avg * Decimal(daysInMonth(month: month, year: year))
    }

    // MARK: - Monthly budget

    /// Fetches the `MonthlyBudget` for `(month, year)`, creating an empty one if
    /// none exists yet (and inserting it so it can be edited in place).
    public static func budgetForMonth(_ month: Int, year: Int, context: ModelContext) -> MonthlyBudget {
        let descriptor = FetchDescriptor<MonthlyBudget>(predicate: #Predicate { $0.month == month && $0.year == year })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let budget = MonthlyBudget(month: month, year: year)
        context.insert(budget)
        return budget
    }

    /// Remaining money after expenses, bills, savings, and investment:
    /// `income - expenses - bills - savings - investment`. Can be negative.
    public static func remainder(income: Decimal, expenses: Decimal, bills: Decimal, savings: Decimal, investment: Decimal) -> Decimal {
        income - expenses - bills - savings - investment
    }

    /// Savings rate as a fraction of income: `(savings + investment + remainder) / income`.
    /// Returns `nil` when `income` is `0` (the rate is undefined). Multiply by
    /// 100 for a percentage.
    public static func savingsRate(savings: Decimal, investment: Decimal, income: Decimal, remainder: Decimal) -> Decimal? {
        guard income > 0 else { return nil }
        return (savings + investment + remainder) / income
    }

    /// Cumulative savings across the given budgets: for each month, sums
    /// `savings + investment + remainder`. `expensesByMonth` supplies each
    /// month's actual expenses so `remainder` can be recomputed historically.
    public static func runningTotalSavings(budgets: [MonthlyBudget], expensesByMonth: [(month: Int, year: Int, total: Decimal)]) -> Decimal {
        let expenseMap = Dictionary(uniqueKeysWithValues: expensesByMonth.map { (key: "\($0.year)-\($0.month)", value: $0.total) })
        return budgets.reduce(Decimal(0)) { total, budget in
            let key = "\(budget.year)-\(budget.month)"
            let expenses = expenseMap[key] ?? Decimal(0)
            let remainder = budget.income - expenses - budget.bills - budget.savings - budget.investment
            return total + budget.savings + budget.investment + remainder
        }
    }

    // MARK: - Tag resolution (private)

    /// Resolves a raw tag name to its canonical form: trimmed and
    /// `Capitalized`. Reuses an existing `Tag` (case-insensitively) or creates
    /// one with a predicted color. Returns the canonical name for the caller to
    /// store on the `Entry`.
    private static func resolveTag(_ rawName: String, context: ModelContext) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespaces)
        let canonical = trimmed.capitalized
        let lower = trimmed.lowercased()

        let descriptor = FetchDescriptor<Tag>()
        if let existingTags = try? context.fetch(descriptor) {
            if let match = existingTags.first(where: { $0.name.lowercased() == lower }) {
                if match.name != canonical {
                    match.name = canonical
                }
                return canonical
            }

            let tag = Tag(name: canonical, colorHex: colorForTag(canonical, allTags: existingTags + [Tag(name: canonical)]))
            context.insert(tag)
            try? context.save()
            return canonical
        }

        let tag = Tag(name: canonical, colorHex: TagPalette.color(at: 0))
        context.insert(tag)
        return canonical
    }

    /// Removes the `Tag` named `name` when no `Entry` references it anymore.
    /// Called after entry deletion or tag change to keep the tag registry clean.
    private static func removeOrphanTag(named name: String, context: ModelContext) {
        let lower = name.lowercased()
        let descriptor = FetchDescriptor<Entry>()
        let allEntries = (try? context.fetch(descriptor)) ?? []
        let remaining = allEntries.filter { $0.tag.lowercased() == lower }.count
        if remaining == 0 {
            let tagDescriptor = FetchDescriptor<Tag>()
            if let allTags = try? context.fetch(tagDescriptor) {
                if let tagToDelete = allTags.first(where: { $0.name.lowercased() == lower }) {
                    context.delete(tagToDelete)
                }
            }
        }
    }
}

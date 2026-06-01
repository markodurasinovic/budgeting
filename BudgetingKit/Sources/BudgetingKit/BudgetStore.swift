import Foundation
import SwiftData

public enum BudgetStore {
    public static func addEntry(date: Date, item: String, tag: String?, amount: Decimal, context: ModelContext) {
        let resolvedTag = resolveTag(tag?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? "Uncategorised", context: context)
        let entry = Entry(date: date, item: item, tag: resolvedTag, amount: amount)
        context.insert(entry)
    }

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

    public static func deleteEntry(_ entry: Entry, context: ModelContext) {
        let tagName = entry.tag
        context.delete(entry)
        removeOrphanTag(named: tagName, context: context)
    }

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
        }

        let tag = Tag(name: canonical)
        context.insert(tag)
        return canonical
    }

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

    public static func entriesForMonth(_ entries: [Entry], month: Int, year: Int) -> [Entry] {
        let calendar = Calendar.current
        return entries.filter { entry in
            let components = calendar.dateComponents([.month, .year], from: entry.date)
            return components.month == month && components.year == year
        }
    }

    public static func totalForMonth(_ entries: [Entry], month: Int, year: Int) -> Decimal {
        entriesForMonth(entries, month: month, year: year).reduce(Decimal(0)) { $0 + $1.amount }
    }

    public static func totalsByTagForMonth(_ entries: [Entry], month: Int, year: Int) -> [(tag: String, total: Decimal)] {
        let monthEntries = entriesForMonth(entries, month: month, year: year)
        var totals: [String: Decimal] = [:]
        for entry in monthEntries {
            totals[entry.tag, default: Decimal(0)] += entry.amount
        }
        return totals.sorted { $0.value > $1.value }.map { (tag: $0.key, total: $0.value) }
    }

    public static func tagColorHex(_ tags: [Tag], for tagName: String) -> String? {
        tags.first(where: { $0.name.lowercased() == tagName.lowercased() })?.colorHex
    }

    public static func searchEntries(_ entries: [Entry], query: String) -> [Entry] {
        guard !query.isEmpty else { return entries }
        let lower = query.lowercased()
        return entries.filter {
            $0.item.lowercased().contains(lower) ||
            $0.tag.lowercased().contains(lower)
        }
    }

    // MARK: - Monthly Budget

    public static func budgetForMonth(_ month: Int, year: Int, context: ModelContext) -> MonthlyBudget {
        let descriptor = FetchDescriptor<MonthlyBudget>(predicate: #Predicate { $0.month == month && $0.year == year })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let budget = MonthlyBudget(month: month, year: year)
        context.insert(budget)
        return budget
    }

    public static func remainder(income: Decimal, expenses: Decimal, bills: Decimal, savings: Decimal, investment: Decimal) -> Decimal {
        income - expenses - bills - savings - investment
    }

    public static func savingsRate(savings: Decimal, investment: Decimal, income: Decimal, remainder: Decimal) -> Decimal? {
        guard income > 0 else { return nil }
        return (savings + investment + remainder) / income
    }

    public static func runningTotalSavings(budgets: [MonthlyBudget], expensesByMonth: [(month: Int, year: Int, total: Decimal)]) -> Decimal {
        let expenseMap = Dictionary(uniqueKeysWithValues: expensesByMonth.map { (key: "\($0.year)-\($0.month)", value: $0.total) })
        return budgets.reduce(Decimal(0)) { total, budget in
            let key = "\(budget.year)-\(budget.month)"
            let expenses = expenseMap[key] ?? Decimal(0)
            let remainder = budget.income - expenses - budget.bills - budget.savings - budget.investment
            return total + budget.savings + budget.investment + remainder
        }
    }
}
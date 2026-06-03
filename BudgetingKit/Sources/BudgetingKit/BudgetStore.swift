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

    private static let tagPalette: [String] = [
        "#007AFF", "#FF9500", "#34C759", "#AF52DE", "#FF2D55",
        "#5AC8FA", "#5856D6", "#FFD60A", "#00C7BE", "#32ADE6",
        "#FF6482", "#44D9E6", "#6C63FF", "#FF6B35", "#B8E6B8",
        "#E6B8B8", "#B8B8E6", "#E6D8B8", "#D8B8E6", "#B8E6D8",
    ]

    private static func unusedColor(from existingTags: [Tag]) -> String {
        var used = Set(existingTags.map { $0.colorHex }.filter { !$0.isEmpty })
        for tag in existingTags where tag.colorHex.isEmpty {
            let hash = tag.name.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
            let idx = abs(hash) % tagPalette.count
            used.insert(tagPalette[idx])
        }
        for color in tagPalette {
            if !used.contains(color) {
                return color
            }
        }
        return tagPalette[existingTags.count % tagPalette.count]
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

            let tag = Tag(name: canonical, colorHex: unusedColor(from: existingTags))
            context.insert(tag)
            try? context.save()
            return canonical
        }

        let tag = Tag(name: canonical, colorHex: tagPalette[0])
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

    public static func daysInMonth(month: Int, year: Int) -> Int {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

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

    public static func averageDailySpend(_ entries: [Entry], month: Int, year: Int) -> Decimal {
        let daysElapsed = daysElapsedInMonth(month: month, year: year)
        guard daysElapsed > 0 else { return Decimal(0) }
        let total = totalForMonth(entries, month: month, year: year)
        return total / Decimal(daysElapsed)
    }

    public static func estimatedMonthlySpend(_ entries: [Entry], month: Int, year: Int) -> Decimal {
        let avg = averageDailySpend(entries, month: month, year: year)
        return avg * Decimal(daysInMonth(month: month, year: year))
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
        guard let tag = tags.first(where: { $0.name.lowercased() == tagName.lowercased() }) else { return nil }
        if !tag.colorHex.isEmpty {
            return tag.colorHex
        }
        var used = Set(tags.map { $0.colorHex }.filter { !$0.isEmpty })
        for t in tags where t.colorHex.isEmpty && t.name != tag.name {
            let h = t.name.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
            used.insert(tagPalette[abs(h) % tagPalette.count])
        }
        for color in tagPalette {
            if !used.contains(color) {
                return color
            }
        }
        return tagPalette[tags.count % tagPalette.count]
    }

    public static func searchEntries(_ entries: [Entry], query: String) -> [Entry] {
        guard !query.isEmpty else { return entries }
        let lower = query.lowercased()
        return entries.filter {
            $0.item.lowercased().contains(lower) ||
            $0.tag.lowercased().contains(lower)
        }
    }

    public static func assignTagColors(in context: ModelContext) {
        let descriptor = FetchDescriptor<Tag>()
        guard let tags = try? context.fetch(descriptor), !tags.isEmpty else { return }

        var used = Set<String>()
        for tag in tags {
            if tag.colorHex.isEmpty { continue }
            if used.contains(tag.colorHex) {
                tag.colorHex = ""
            } else {
                used.insert(tag.colorHex)
            }
        }

        var unassigned = tags.filter { $0.colorHex.isEmpty }
        for tag in unassigned {
            for color in tagPalette {
                if !used.contains(color) {
                    tag.colorHex = color
                    used.insert(color)
                    break
                }
            }
            if tag.colorHex.isEmpty {
                let idx = used.count % tagPalette.count
                tag.colorHex = tagPalette[idx]
                used.insert(tagPalette[idx])
            }
        }
        try? context.save()
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
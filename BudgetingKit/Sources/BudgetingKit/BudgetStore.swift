import Foundation
import SwiftData

public enum BudgetStore {
    public static func addEntry(date: Date, item: String, tag: String?, amount: Decimal, context: ModelContext) {
        let resolvedTag = tag?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? item.trimmingCharacters(in: .whitespaces)
        ensureTagExists(named: resolvedTag, context: context)
        let entry = Entry(date: date, item: item, tag: resolvedTag, amount: amount)
        context.insert(entry)
    }

    public static func updateEntry(_ entry: Entry, date: Date, item: String, tag: String?, amount: Decimal, context: ModelContext) {
        let resolvedTag = tag?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? item.trimmingCharacters(in: .whitespaces)
        entry.date = date
        entry.item = item
        entry.tag = resolvedTag
        entry.amount = amount
        ensureTagExists(named: resolvedTag, context: context)
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

    private static func removeOrphanTag(named name: String, context: ModelContext) {
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.tag == name })
        let remaining = (try? context.fetch(descriptor).count) ?? 0
        if remaining == 0 {
            let tagDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.name == name })
            if let tag = try? context.fetch(tagDescriptor).first {
                context.delete(tag)
            }
        }
    }

    public static func ensureTagExists(named name: String, context: ModelContext) {
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.name == name })
        if (try? context.fetch(descriptor).first) != nil { return }
        let tag = Tag(name: name)
        context.insert(tag)
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
        tags.first(where: { $0.name == tagName })?.colorHex
    }

    public static func searchEntries(_ entries: [Entry], query: String) -> [Entry] {
        guard !query.isEmpty else { return entries }
        let lower = query.lowercased()
        return entries.filter {
            $0.item.lowercased().contains(lower) ||
            $0.tag.lowercased().contains(lower)
        }
    }
}
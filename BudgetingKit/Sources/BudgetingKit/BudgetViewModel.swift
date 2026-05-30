import Foundation
import SwiftData

@MainActor
public final class BudgetViewModel: ObservableObject {
    public let modelContext: ModelContext

    @Published public var entries: [Entry] = []
    @Published public var tags: [Tag] = []
    @Published public var errorMessage: String?

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchAll()
    }

    public func fetchAll() {
        do {
            let entryDescriptor = FetchDescriptor<Entry>(sortBy: [
                SortDescriptor(\.date, order: .reverse),
                SortDescriptor(\.item),
            ])
            entries = try modelContext.fetch(entryDescriptor)

            let tagDescriptor = FetchDescriptor<Tag>(sortBy: [
                SortDescriptor(\.name),
            ])
            tags = try modelContext.fetch(tagDescriptor)
            errorMessage = nil
        } catch {
            entries = []
            tags = []
            errorMessage = error.localizedDescription
        }
    }

    public func addEntry(date: Date, item: String, tag: String, amount: Decimal) {
        ensureTagExists(named: tag)

        let entry = Entry(date: date, item: item, tag: tag, amount: amount)
        modelContext.insert(entry)
        fetchAll()
    }

    public func updateEntry(_ entry: Entry, date: Date, item: String, tag: String, amount: Decimal) {
        entry.date = date
        entry.item = item
        entry.tag = tag
        entry.amount = amount
        ensureTagExists(named: tag)
        fetchAll()
    }

    public func deleteEntry(_ entry: Entry) {
        modelContext.delete(entry)
        fetchAll()
    }

    public func entriesForMonth(_ month: Int, year: Int) -> [Entry] {
        let calendar = Calendar.current
        return entries.filter { entry in
            let components = calendar.dateComponents([.month, .year], from: entry.date)
            return components.month == month && components.year == year
        }
    }

    public func totalForMonth(_ month: Int, year: Int) -> Decimal {
        entriesForMonth(month, year: year).reduce(Decimal(0)) { $0 + $1.amount }
    }

    public func totalsByTagForMonth(_ month: Int, year: Int) -> [(tag: String, total: Decimal)] {
        let monthEntries = entriesForMonth(month, year: year)
        var totals: [String: Decimal] = [:]
        for entry in monthEntries {
            totals[entry.tag, default: Decimal(0)] += entry.amount
        }
        return totals.sorted { $0.value > $1.value }.map { (tag: $0.key, total: $0.value) }
    }

    public func allTagNames() -> [String] {
        tags.map(\.name).sorted()
    }

    public func tagColor(for tagName: String) -> String? {
        tags.first(where: { $0.name == tagName })?.colorHex
    }

    public func searchEntries(query: String) -> [Entry] {
        guard !query.isEmpty else { return entries }
        let lower = query.lowercased()
        return entries.filter {
            $0.item.lowercased().contains(lower) ||
            $0.tag.lowercased().contains(lower)
        }
    }

    public func deleteEntries(_ entriesToDelete: [Entry]) {
        for entry in entriesToDelete {
            modelContext.delete(entry)
        }
        fetchAll()
    }

    private func ensureTagExists(named name: String) {
        if tags.contains(where: { $0.name == name }) { return }
        let tag = Tag(name: name)
        modelContext.insert(tag)
        tags.append(tag)
        tags.sort(by: { $0.name < $1.name })
    }
}
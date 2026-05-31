import SwiftUI
import SwiftData
import BudgetingKit

struct TagSummaryView: View {
    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.item)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    @State private var selectedMonth = Date()

    private var month: Int {
        Calendar.current.component(.month, from: selectedMonth)
    }

    private var year: Int {
        Calendar.current.component(.year, from: selectedMonth)
    }

    private var entryCountForTag: [String: Int] {
        var counts: [String: Int] = [:]
        for entry in entries {
            counts[entry.tag, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        NavigationStack {
            List {
                Section("All Tags") {
                    if tags.isEmpty {
                        ContentUnavailableView(
                            "No tags",
                            systemImage: "tag",
                            description: Text("Add entries with tags to see them here")
                        )
                    } else {
                        ForEach(tags, id: \.name) { tag in
                            let count = entryCountForTag[tag.name, default: 0]
                            NavigationLink(value: tag.name) {
                                HStack {
                                    Circle()
                                        .fill(Color.hex(tag.name, from: tag.colorHex.isEmpty ? nil : tag.colorHex))
                                        .frame(width: 12, height: 12)
                                    Text(tag.name)
                                    Spacer()
                                    Text("\(count) entries")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                let tagTotals = BudgetStore.totalsByTagForMonth(entries, month: month, year: year)
                if !tagTotals.isEmpty {
                    Section(selectedMonth.formatted(.dateTime.year().month(.wide))) {
                        ForEach(tagTotals, id: \.tag) { item in
                            HStack {
                                Circle()
                                    .fill(Color.hex(item.tag, from: BudgetStore.tagColorHex(tags, for: item.tag)))
                                    .frame(width: 12, height: 12)
                                Text(item.tag)
                                Spacer()
                                Text(MoneyHelper.format(item.total))
                                    .foregroundStyle(item.total < 0 ? .red : .primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationDestination(for: String.self) { tagName in
                TagDetailView(tagName: tagName, month: month, year: year)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonthPicker(selection: $selectedMonth)
                }
            }
        }
    }
}

#Preview {
    TagSummaryView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
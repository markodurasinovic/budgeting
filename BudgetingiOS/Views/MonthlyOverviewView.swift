import SwiftUI
import SwiftData
import BudgetingKit

struct MonthlyOverviewView: View {
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

    private var monthName: String {
        selectedMonth.formatted(.dateTime.year().month(.wide))
    }

    var body: some View {
        NavigationStack {
            let total = BudgetStore.totalForMonth(entries, month: month, year: year)
            let tagTotals = BudgetStore.totalsByTagForMonth(entries, month: month, year: year)
            let monthEntries = BudgetStore.entriesForMonth(entries, month: month, year: year)

            List {
                Section(monthName) {
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(MoneyHelper.format(total))
                            .font(.headline)
                            .foregroundStyle(total < 0 ? .red : .primary)
                    }

                    HStack {
                        Text("Entries")
                            .font(.subheadline)
                        Spacer()
                        Text("\(monthEntries.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("By tag") {
                    if tagTotals.isEmpty {
                        Text("No entries this month")
                            .foregroundStyle(.secondary)
                    }
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

                Section("Recent entries") {
                    let recent = Array(monthEntries.prefix(5))
                    if recent.isEmpty {
                        Text("No entries this month")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(recent, id: \.id) { entry in
                        EntryRowView(entry: entry)
                    }
                }
            }
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonthPicker(selection: $selectedMonth)
                }
            }
        }
    }
}

#Preview {
    MonthlyOverviewView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
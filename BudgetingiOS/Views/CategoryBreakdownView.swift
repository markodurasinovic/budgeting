import SwiftUI
import SwiftData
import BudgetingKit

struct CategoryBreakdownView: View {
    @Environment(\.modelContext) private var modelContext
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

    private var tagTotals: [(tag: String, total: Decimal)] {
        BudgetStore.totalsByTagForMonth(entries, month: month, year: year)
    }

    private var totalExpenses: Decimal {
        tagTotals.reduce(Decimal(0)) { $0 + $1.total }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    HStack {
                        Text("Total expenses")
                        Spacer()
                        Text(MoneyHelper.format(totalExpenses))
                            .fontWeight(.semibold)
                    }
                }

                Section(selectedMonth.formatted(.dateTime.year().month(.wide))) {
                    if tagTotals.isEmpty {
                        Text("No entries this month")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(tagTotals, id: \.tag) { item in
                        let pct = totalExpenses > 0 ? NSDecimalNumber(decimal: item.total / totalExpenses).doubleValue * 100 : 0
                        VStack(spacing: 6) {
                            HStack {
                                Circle()
                                    .fill(Color.hex(item.tag, from: BudgetStore.tagColorHex(tags, for: item.tag)))
                                    .frame(width: 10, height: 10)
                                Text(item.tag)
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.1f%%", pct))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(MoneyHelper.format(item.total))
                                    .font(.subheadline)
                                    .foregroundStyle(item.total < 0 ? .red : .primary)
                                    .frame(minWidth: 60, alignment: .trailing)
                            }
                            LinearProgressBar(value: item.total, total: totalExpenses, color: Color.hex(item.tag, from: BudgetStore.tagColorHex(tags, for: item.tag)))
                        }
                    }
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonthPicker(selection: $selectedMonth)
                }
            }
        }
    }
}

struct LinearProgressBar: View {
    let value: Decimal
    let total: Decimal
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary)
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: total > 0 ? geo.size.width * min(1, CGFloat(truncating: NSDecimalNumber(decimal: value / total))) : 0, height: 6)
            }
        }
        .frame(height: 6)
    }
}

#Preview {
    CategoryBreakdownView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
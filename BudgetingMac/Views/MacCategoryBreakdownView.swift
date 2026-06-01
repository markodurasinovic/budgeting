import SwiftUI
import SwiftData
import BudgetingKit

struct MacCategoryBreakdownView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse), SortDescriptor(\Entry.item)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    let month: Int
    let year: Int

    private var tagTotals: [(tag: String, total: Decimal)] {
        BudgetStore.totalsByTagForMonth(entries, month: month, year: year)
    }

    private var totalExpenses: Decimal {
        tagTotals.reduce(Decimal(0)) { $0 + $1.total }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            HStack {
                Text("Total: ")
                    .foregroundStyle(.secondary)
                Text(MoneyHelper.format(totalExpenses))
                    .fontWeight(.semibold)
            }
            .padding(.horizontal)

            List {
                ForEach(tagTotals, id: \.tag) { item in
                    let pct = totalExpenses > 0 ? NSDecimalNumber(decimal: item.total / totalExpenses).doubleValue * 100 : 0
                    VStack(spacing: 6) {
                        HStack {
                            Circle()
                                .fill(Color.hex(item.tag, from: BudgetStore.tagColorHex(tags, for: item.tag)))
                                .frame(width: 10, height: 10)
                            Text(item.tag)
                            Spacer()
                            Text(String(format: "%.1f%%", pct))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(MoneyHelper.format(item.total))
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                        MacLinearProgressBar(value: item.total, total: totalExpenses, color: Color.hex(item.tag, from: BudgetStore.tagColorHex(tags, for: item.tag)))
                    }
                }
            }
            .listStyle(.plain)
        }
        .padding(.top)
    }
}

struct MacLinearProgressBar: View {
    let value: Decimal
    let total: Decimal
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: total > 0 ? geo.size.width * min(1, CGFloat(truncating: NSDecimalNumber(decimal: value / total))) : 0, height: 8)
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    MacCategoryBreakdownView(month: 5, year: 2026)
        .modelContainer(BudgetingContainer.makePreviewContainer())
        .frame(width: 500, height: 400)
}
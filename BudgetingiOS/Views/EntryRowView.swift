import SwiftUI
import BudgetingKit

struct EntryRowView: View {
    let entry: Entry

    private var entryDate: String {
        entry.date.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.item)
                    .font(.body)
                Text(entry.tag)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyHelper.format(entry.amount))
                    .font(.body)
                    .foregroundStyle(entry.amount < 0 ? .red : .primary)
                Text(entryDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    List {
        EntryRowView(entry: Entry(item: "Groceries", tag: "Food", amount: Decimal(string: "45.50")!))
        EntryRowView(entry: Entry(item: "Salary", tag: "Income", amount: Decimal(string: "3500")!))
    }
    .modelContainer(BudgetingContainer.makePreviewContainer())
}
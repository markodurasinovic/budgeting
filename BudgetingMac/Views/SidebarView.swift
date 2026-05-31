import SwiftUI
import SwiftData
import BudgetingKit

struct SidebarView: View {
    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    @Binding var selectedMonth: Date
    @Binding var selectedTag: String?

    private var monthName: String {
        selectedMonth.formatted(.dateTime.year().month(.wide))
    }

    private var entryCountForTag: [String: Int] {
        var counts: [String: Int] = [:]
        for entry in entries {
            counts[entry.tag, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        List(selection: $selectedTag) {
            Section("Filter") {
                Label("All Entries", systemImage: "list.bullet")
                    .tag("___ALL___" as String)
            }

            Section("Months") {
                HStack {
                    Button {
                        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
                            selectedMonth = prev
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    Text(monthName)
                        .font(.headline)

                    Spacer()

                    Button {
                        if let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) {
                            selectedMonth = next
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    Button("Today") {
                        selectedMonth = Date()
                    }
                    .buttonStyle(.borderless)
                }
            }

            if !tags.isEmpty {
                Section("Tags") {
                    ForEach(tags, id: \.name) { tag in
                        let count = entryCountForTag[tag.name, default: 0]
                        HStack {
                            Circle()
                                .fill(Color.hex(tag.name, from: tag.colorHex.isEmpty ? nil : tag.colorHex))
                                .frame(width: 10, height: 10)
                            Text(tag.name)
                            Spacer()
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(tag.name as String)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Budgeting")
    }
}

#Preview {
    SidebarView(selectedMonth: .constant(Date()), selectedTag: .constant(nil))
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
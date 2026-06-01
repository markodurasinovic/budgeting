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

    private var month: Int {
        Calendar.current.component(.month, from: selectedMonth)
    }

    private var year: Int {
        Calendar.current.component(.year, from: selectedMonth)
    }

    private var monthEntries: [Entry] {
        BudgetStore.entriesForMonth(entries, month: month, year: year)
    }

    private var entryCountForTag: [String: Int] {
        var counts: [String: Int] = [:]
        for entry in monthEntries {
            counts[entry.tag, default: 0] += 1
        }
        return counts
    }

    private var tagsInMonth: [String] {
        let tagSet = Set(monthEntries.map(\.tag))
        return tags.filter { tagSet.contains($0.name) }.map(\.name).sorted()
    }

    var body: some View {
        List(selection: $selectedTag) {
            Section("Filter") {
                Label("All Entries", systemImage: "list.bullet")
                    .tag("___ALL___" as String)
                Label("Categories", systemImage: "chart.bar.fill")
                    .tag("___CATEGORIES___" as String)
                Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis")
                    .tag("___PORTFOLIO___" as String)
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

            if !tagsInMonth.isEmpty {
                Section("Tags") {
                    ForEach(tagsInMonth, id: \.self) { tagName in
                        let count = entryCountForTag[tagName, default: 0]
                        HStack {
                            Circle()
                                .fill(Color.hex(tagName, from: BudgetStore.tagColorHex(tags, for: tagName)))
                                .frame(width: 10, height: 10)
                            Text(tagName)
                            Spacer()
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(tagName as String)
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
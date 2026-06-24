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

    struct Snapshot {
        let tagsInMonth: [String]
        let entryCountForTag: [String: Int]
        let tagColors: [String: Color]
    }

    private var snapshot: Snapshot {
        let cal = Calendar.current
        var counts: [String: Int] = [:]
        var tagsInMonthSet = Set<String>()
        for entry in entries {
            let comps = cal.dateComponents([.month, .year], from: entry.date)
            if comps.month == month && comps.year == year {
                counts[entry.tag, default: 0] += 1
                tagsInMonthSet.insert(entry.tag)
            }
        }
        let tagsInMonth = tags.filter { tagsInMonthSet.contains($0.name) }.map(\.name).sorted()

        var tagColors: [String: Color] = [:]
        for tag in tags {
            tagColors[tag.name] = Color.hex(tag.name, from: BudgetStore.tagColorHex(tags, for: tag.name))
        }

        return Snapshot(tagsInMonth: tagsInMonth, entryCountForTag: counts, tagColors: tagColors)
    }

    var body: some View {
        let snap = snapshot
        return List(selection: $selectedTag) {
            Section("Filter") {
                Label("All Entries", systemImage: "list.bullet")
                    .tag("___ALL___" as String)
                Label("Categories", systemImage: "chart.bar.fill")
                    .tag("___CATEGORIES___" as String)
                Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis")
                    .tag("___PORTFOLIO___" as String)
                Label("Daily Spend", systemImage: "calendar")
                    .tag("___DAILY___" as String)
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

            if !snap.tagsInMonth.isEmpty {
                Section("Tags") {
                    ForEach(snap.tagsInMonth, id: \.self) { tagName in
                        let count = snap.entryCountForTag[tagName, default: 0]
                        HStack {
                            Circle()
                                .fill(snap.tagColors[tagName] ?? Color.hex(tagName, from: nil))
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
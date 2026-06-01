import SwiftUI
import SwiftData
import BudgetingKit

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Entry.date, order: .reverse)])
    private var entries: [Entry]

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    @Binding var selectedMonth: Date
    @Binding var selectedTag: String?

    @State private var showingClearAlert = false

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

            Section {
                Button("Clear All Data", role: .destructive) {
                    showingClearAlert = true
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .alert("Clear All Data?", isPresented: $showingClearAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Clear", role: .destructive) {
                        performClear()
                    }
                } message: {
                    Text("This will delete all entries, tags, and budgets. This cannot be undone.")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Budgeting")
    }

    private func performClear() {
        let entryDescriptor = FetchDescriptor<Entry>()
        let tagDescriptor = FetchDescriptor<Tag>()
        let budgetDescriptor = FetchDescriptor<MonthlyBudget>()

        if let entries = try? modelContext.fetch(entryDescriptor) {
            for e in entries { modelContext.delete(e) }
        }
        if let tags = try? modelContext.fetch(tagDescriptor) {
            for t in tags { modelContext.delete(t) }
        }
        if let budgets = try? modelContext.fetch(budgetDescriptor) {
            for b in budgets { modelContext.delete(b) }
        }
    }
}

#Preview {
    SidebarView(selectedMonth: .constant(Date()), selectedTag: .constant(nil))
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
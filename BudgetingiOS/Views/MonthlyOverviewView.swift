import SwiftUI
import SwiftData
import BudgetingKit

struct MonthlyOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BudgetViewModel?
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
            Group {
                if let vm = viewModel {
                    let total = vm.totalForMonth(month, year: year)
                    let tagTotals = vm.totalsByTagForMonth(month, year: year)

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
                                Text("\(vm.entriesForMonth(month, year: year).count)")
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
                                        .fill(Color.hex(item.tag, from: vm.tagColor(for: item.tag)))
                                        .frame(width: 12, height: 12)
                                    Text(item.tag)
                                    Spacer()
                                    Text(MoneyHelper.format(item.total))
                                        .foregroundStyle(item.total < 0 ? .red : .primary)
                                }
                            }
                        }

                        Section("Recent entries") {
                            let recent = vm.entriesForMonth(month, year: year).prefix(5)
                            if recent.isEmpty {
                                Text("No entries this month")
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(Array(recent), id: \.id) { entry in
                                EntryRowView(entry: entry)
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonthPicker(selection: $selectedMonth)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = BudgetViewModel(modelContext: modelContext)
            }
        }
        .onChange(of: selectedMonth) {
            viewModel?.fetchAll()
        }
    }
}

#Preview {
    MonthlyOverviewView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
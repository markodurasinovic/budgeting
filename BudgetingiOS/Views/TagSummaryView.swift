import SwiftUI
import SwiftData
import BudgetingKit

struct TagSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BudgetViewModel?
    @State private var selectedTag: String?
    @State private var selectedMonth = Date()

    private var month: Int {
        Calendar.current.component(.month, from: selectedMonth)
    }

    private var year: Int {
        Calendar.current.component(.year, from: selectedMonth)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    let tagTotals = vm.totalsByTagForMonth(month, year: year)

                    List {
                        if tagTotals.isEmpty {
                            ContentUnavailableView(
                                "No tags",
                                systemImage: "tag",
                                description: Text("Add entries with tags to see them here")
                            )
                        } else {
                            ForEach(tagTotals, id: \.tag) { item in
                                NavigationLink(value: item.tag) {
                                    HStack {
                                        Circle()
                                            .fill(Color.hex(item.tag, from: vm.tagColor(for: item.tag)))
                                            .frame(width: 12, height: 12)
                                        Text(item.tag)
                                            .font(.body)
                                        Spacer()
                                        Text(MoneyHelper.format(item.total))
                                            .foregroundStyle(item.total < 0 ? .red : .primary)
                                    }
                                }
                            }
                        }
                    }
                    .navigationDestination(for: String.self) { tagName in
                        TagDetailView(tagName: tagName, month: month, year: year)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Tags")
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
    TagSummaryView()
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
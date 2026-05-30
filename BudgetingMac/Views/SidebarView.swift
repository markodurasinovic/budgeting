import SwiftUI
import BudgetingKit

struct SidebarView: View {
    let viewModel: BudgetViewModel?
    @Binding var selectedMonth: Date
    @Binding var selectedTag: String?

    private var tagNames: [String] {
        viewModel?.allTagNames() ?? []
    }

    var body: some View {
        List(selection: $selectedTag) {
            Section("Months") {
                MonthNavigationRow(date: selectedMonth, selectedMonth: $selectedMonth)
            }

            if !tagNames.isEmpty {
                Section("Tags") {
                    ForEach(tagNames, id: \.self) { tag in
                        HStack {
                            Circle()
                                .fill(Color.hex(tag, from: viewModel?.tagColor(for: tag)))
                                .frame(width: 10, height: 10)
                            Text(tag)
                        }
                        .tag(tag)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Budgeting")
    }
}

struct MonthNavigationRow: View {
    let date: Date
    @Binding var selectedMonth: Date

    private var monthName: String {
        date.formatted(.dateTime.year().month(.wide))
    }

    var body: some View {
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
}

#Preview {
    SidebarView(viewModel: nil, selectedMonth: .constant(Date()), selectedTag: .constant(nil))
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
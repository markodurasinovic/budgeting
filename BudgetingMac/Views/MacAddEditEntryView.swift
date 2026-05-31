import SwiftUI
import SwiftData
import BudgetingKit

struct MacAddEditEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case add
        case edit(Entry)
    }

    let mode: Mode

    @State private var date = Date()
    @State private var item = ""
    @State private var tag = ""
    @State private var amountText = ""
    @State private var viewModel: BudgetViewModel?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Entry" : "New Entry")
                .font(.headline)

            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Item", text: $item)
                TextField("Tag", text: $tag)
                TextField("Amount", text: $amountText)

                if let vm = viewModel {
                    let suggestions = vm.allTagNames().filter { existing in
                        !tag.isEmpty && existing.localizedCaseInsensitiveContains(tag) && existing != tag
                    }
                    if !suggestions.isEmpty {
                        LabeledContent("Suggestions") {
                            WrappingHStack(tags: suggestions, onSelect: { selected in
                                tag = selected
                            })
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    saveEntry()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 400, height: isEditing ? 380 : 360)
        .onAppear {
            if case .edit(let entry) = mode {
                date = entry.date
                item = entry.item
                tag = entry.tag
                amountText = MoneyHelper.format(entry.amount).replacingOccurrences(of: "£", with: "")
            }
            viewModel = BudgetViewModel(modelContext: modelContext)
        }
    }

    private var isValid: Bool {
        !item.trimmingCharacters(in: .whitespaces).isEmpty
            && !tag.trimmingCharacters(in: .whitespaces).isEmpty
            && MoneyHelper.parse(amountText) != nil
    }

    private func saveEntry() {
        guard let amount = MoneyHelper.parse(amountText),
              let vm = viewModel else { return }

        let trimmedItem = item.trimmingCharacters(in: .whitespaces)
        let trimmedTag = tag.trimmingCharacters(in: .whitespaces)

        switch mode {
        case .add:
            vm.addEntry(date: date, item: trimmedItem, tag: trimmedTag, amount: amount)
        case .edit(let entry):
            vm.updateEntry(entry, date: date, item: trimmedItem, tag: trimmedTag, amount: amount)
        }

        dismiss()
    }
}

struct WrappingHStack: View {
    let tags: [String]
    let onSelect: (String) -> Void

    var body: some View {
        FlowLayout(tags: tags, onSelect: onSelect)
    }
}

struct FlowLayout: View {
    let tags: [String]
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Button(tag) {
                    onSelect(tag)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

#Preview("Add") {
    MacAddEditEntryView(mode: .add)
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
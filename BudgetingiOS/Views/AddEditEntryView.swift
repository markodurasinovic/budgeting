import SwiftUI
import SwiftData
import BudgetingKit

enum AddEditMode {
    case add
    case edit(Entry)
}

struct AddEditEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: AddEditMode

    @State private var date = Date()
    @State private var item = ""
    @State private var tag = ""
    @State private var amountText = ""
    @State private var viewModel: BudgetViewModel?
    @FocusState private var focusedField: Field?

    private enum Field {
        case item, tag, amount
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    TextField("Item", text: $item)
                        .focused($focusedField, equals: .item)

                    TextField("Tag", text: $tag)
                        .focused($focusedField, equals: .tag)

                    TextField("Amount", text: $amountText)
                        .focused($focusedField, equals: .amount)
                        .keyboardType(.decimalPad)
                }

                if let vm = viewModel {
                    let suggestions = vm.allTagNames().filter { existing in
                        !tag.isEmpty && existing.localizedCaseInsensitiveContains(tag) && existing != tag
                    }
                    if !suggestions.isEmpty {
                        Section("Suggestions") {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(suggestion) {
                                    tag = suggestion
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Entry" : "Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveEntry()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if case .edit(let entry) = mode {
                    date = entry.date
                    item = entry.item
                    tag = entry.tag
                    amountText = MoneyHelper.format(entry.amount).replacingOccurrences(of: "£", with: "")
                }
                focusedField = .item
                viewModel = BudgetViewModel(modelContext: modelContext)
            }
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

#Preview("Add") {
    AddEditEntryView(mode: .add)
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
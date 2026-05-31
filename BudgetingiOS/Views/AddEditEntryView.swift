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

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    let mode: AddEditMode

    @State private var date = Date()
    @State private var item = ""
    @State private var tag = ""
    @State private var amountText = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case item, tag, amount
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var tagSuggestions: [String] {
        let allNames = tags.map(\.name)
        return allNames.filter { existing in
            !tag.isEmpty && existing.localizedCaseInsensitiveContains(tag) && existing != tag
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    TextField("Item", text: $item)
                        .focused($focusedField, equals: .item)

                    TextField("Tag (optional)", text: $tag)
                        .focused($focusedField, equals: .tag)

                    TextField("Amount", text: $amountText)
                        .focused($focusedField, equals: .amount)
                        .keyboardType(.decimalPad)
                }

                if !tagSuggestions.isEmpty {
                    Section("Suggestions") {
                        ForEach(tagSuggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                tag = suggestion
                            }
                        }
                    }
                }

                if isEditing {
                    Section {
                        Button("Delete Entry", role: .destructive) {
                            deleteEntry()
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
            }
        }
    }

    private var isValid: Bool {
        !item.trimmingCharacters(in: .whitespaces).isEmpty
            && MoneyHelper.parse(amountText) != nil
    }

    private func saveEntry() {
        guard let amount = MoneyHelper.parse(amountText) else { return }

        let trimmedItem = item.trimmingCharacters(in: .whitespaces)
        let trimmedTag = tag.trimmingCharacters(in: .whitespaces).nilIfEmpty

        switch mode {
        case .add:
            BudgetStore.addEntry(date: date, item: trimmedItem, tag: trimmedTag, amount: amount, context: modelContext)
        case .edit(let entry):
            BudgetStore.updateEntry(entry, date: date, item: trimmedItem, tag: trimmedTag, amount: amount, context: modelContext)
        }

        dismiss()
    }

    private func deleteEntry() {
        guard case .edit(let entry) = mode else { return }
        BudgetStore.deleteEntry(entry, context: modelContext)
        dismiss()
    }
}

#Preview("Add") {
    AddEditEntryView(mode: .add)
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
import SwiftUI
import SwiftData
import BudgetingKit

struct MacAddEditEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    enum Mode {
        case add
        case edit(Entry)
    }

    let mode: Mode

    @State private var date = Date()
    @State private var item = ""
    @State private var tag = ""
    @State private var amountText = ""

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
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Entry" : "New Entry")
                .font(.headline)

            Form {
                TextField("Item", text: $item)
                TextField("Tag (optional)", text: $tag)
                TextField("Amount", text: $amountText)
                DatePicker("Date", selection: $date, displayedComponents: .date)

                if !tagSuggestions.isEmpty {
                    LabeledContent("Suggestions") {
                        HStack(spacing: 6) {
                            ForEach(tagSuggestions, id: \.self) { suggestion in
                                Button(suggestion) {
                                    tag = suggestion
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if isEditing {
                    Button("Delete", role: .destructive) {
                        deleteEntry()
                    }
                }
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
    MacAddEditEntryView(mode: .add)
        .modelContainer(BudgetingContainer.makePreviewContainer())
}

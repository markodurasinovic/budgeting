import SwiftUI
import SwiftData
import BudgetingKit

struct MacAddEditEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    enum Mode {
        case add(initialDate: Date?)
        case edit(Entry)
    }

    let mode: Mode

    @State private var date: Date
    @State private var rows: [EntryRow] = [EntryRow()]
    @State private var editingEntry: Entry?
    @State private var editingItem = ""
    @State private var editingTag = ""
    @State private var editingAmountText = ""

    struct EntryRow: Identifiable {
        let id = UUID()
        var item = ""
        var tag = ""
        var amountText = ""
    }

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add(let initialDate):
            _date = State(initialValue: initialDate ?? Date())
            _rows = State(initialValue: [EntryRow()])
        case .edit(let entry):
            _date = State(initialValue: entry.date)
            _editingEntry = State(initialValue: entry)
            _editingItem = State(initialValue: entry.item)
            _editingTag = State(initialValue: entry.tag)
            _editingAmountText = State(initialValue: MoneyHelper.format(entry.amount).replacingOccurrences(of: "£", with: ""))
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var allTagNames: [String] {
        tags.map(\.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Entry" : "New Entries")
                .font(.headline)
                .padding(.top, 16)

            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)

                if isEditing {
                    editForm
                } else {
                    addForm
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
        .frame(width: 540, height: isEditing ? 340 : max(340, 200 + CGFloat(rows.count) * 70))
    }

    private var editForm: some View {
        Group {
            TextField("Item", text: $editingItem)
            tagField(text: $editingTag, allTags: allTagNames)
            TextField("Amount", text: $editingAmountText)
        }
    }

    private var addForm: some View {
        Section {
            ForEach($rows) { $row in
                HStack(alignment: .top) {
                    VStack(spacing: 6) {
                        TextField("Item", text: $row.item)
                        tagField(text: $row.tag, allTags: allTagNames)
                        TextField("Amount", text: $row.amountText)
                    }
                    if rows.count > 1 {
                        Button {
                            rows.removeAll { $0.id == row.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .padding(.top, 6)
                    }
                }
            }
            Button {
                rows.append(EntryRow())
            } label: {
                Label("Add row", systemImage: "plus")
            }
        }
    }

    private func tagField(text: Binding<String>, allTags: [String]) -> some View {
        let suggestions = allTags.filter { existing in
            !text.wrappedValue.isEmpty && existing.localizedCaseInsensitiveContains(text.wrappedValue) && existing != text.wrappedValue
        }
        return VStack(spacing: 4) {
            TextField("Tag (optional)", text: text)
            if !suggestions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                        Button(suggestion) {
                            text.wrappedValue = suggestion
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        if isEditing {
            return !editingItem.trimmingCharacters(in: .whitespaces).isEmpty
                && MoneyHelper.parse(editingAmountText) != nil
        }
        return rows.allSatisfy { row in
            !row.item.trimmingCharacters(in: .whitespaces).isEmpty
                && MoneyHelper.parse(row.amountText) != nil
        }
    }

    private func saveEntry() {
        switch mode {
        case .edit(let entry):
            guard let amount = MoneyHelper.parse(editingAmountText) else { return }
            let trimmedItem = editingItem.trimmingCharacters(in: .whitespaces)
            let trimmedTag = editingTag.trimmingCharacters(in: .whitespaces).nilIfEmpty
            BudgetStore.updateEntry(entry, date: date, item: trimmedItem, tag: trimmedTag, amount: amount, context: modelContext)
        case .add:
            for row in rows {
                guard let amount = MoneyHelper.parse(row.amountText) else { continue }
                let trimmedItem = row.item.trimmingCharacters(in: .whitespaces)
                let trimmedTag = row.tag.trimmingCharacters(in: .whitespaces).nilIfEmpty
                BudgetStore.addEntry(date: date, item: trimmedItem, tag: trimmedTag, amount: amount, context: modelContext)
            }
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
    MacAddEditEntryView(mode: .add(initialDate: nil))
        .modelContainer(BudgetingContainer.makePreviewContainer())
}
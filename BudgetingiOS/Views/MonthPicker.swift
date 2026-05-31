import SwiftUI

struct MonthPicker: View {
    @Binding var selection: Date

    var body: some View {
        Menu {
            Button("Previous month") {
                if let prev = Calendar.current.date(byAdding: .month, value: -1, to: selection) {
                    selection = prev
                }
            }
            Button("Current month") {
                selection = Date()
            }
            Button("Next month") {
                if let next = Calendar.current.date(byAdding: .month, value: 1, to: selection) {
                    selection = next
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(selection.formatted(.dateTime.year().month(.abbreviated)))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
    }
}

#Preview {
    MonthPicker(selection: .constant(Date()))
}
import WidgetKit
import SwiftUI
import BudgetingKit

/// Timeline entry rendered by the widget. All numeric fields are `Double`/`Int`
/// because they're read from `UserDefaults` (which doesn't store `Decimal`).
/// `date` is required by `TimelineEntry` and is set by the timeline provider.
struct BudgetEntry: TimelineEntry {
    let date: Date
    let remainder: Double
    let dailyBudget: Double
    let income: Double
    let bills: Double
    let expenses: Double
    let savings: Double
    let investment: Double
    let daysRemaining: Int
    let daysElapsed: Int
    let totalDays: Int
    let hasData: Bool
    let month: Int
    let year: Int

    /// Builds an entry from a `WidgetData.Snapshot` (read from shared
    /// UserDefaults) plus the `date` the timeline wants to render at. A static
    /// factory rather than an `init` so the synthesized memberwise initializer
    /// stays available for the `#Preview` below.
    static func make(date: Date, snapshot: WidgetData.Snapshot) -> BudgetEntry {
        BudgetEntry(
            date: date,
            remainder: snapshot.remainder,
            dailyBudget: snapshot.dailyBudget,
            income: snapshot.income,
            bills: snapshot.bills,
            expenses: snapshot.expenses,
            savings: snapshot.savings,
            investment: snapshot.investment,
            daysRemaining: snapshot.daysRemaining,
            daysElapsed: snapshot.daysElapsed,
            totalDays: snapshot.totalDays,
            hasData: snapshot.hasData,
            month: snapshot.month,
            year: snapshot.year
        )
    }

    /// A placeholder entry with zeroed values, used by WidgetKit before real
    /// data is available and as a fallback when no snapshot exists.
    static var placeholder: BudgetEntry {
        BudgetEntry(
            date: Date(),
            remainder: 0, dailyBudget: 0,
            income: 0, bills: 0, expenses: 0,
            savings: 0, investment: 0,
            daysRemaining: 0, daysElapsed: 0, totalDays: 30,
            hasData: false,
            month: Calendar.current.component(.month, from: Date()),
            year: Calendar.current.component(.year, from: Date())
        )
    }
}

/// Provides the widget's timeline by reading the snapshot written by the app
/// via `WidgetData`. Refreshes are requested every 4 hours; the app also
/// triggers an immediate refresh after any entry/budget change.
struct BudgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        completion(currentEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let entry = currentEntry() ?? .placeholder
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: Date())
            ?? Date().addingTimeInterval(14400)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    /// Reads the latest snapshot and wraps it in an entry dated `now`.
    private func currentEntry() -> BudgetEntry? {
        guard let snapshot = WidgetData.read() else { return nil }
        return BudgetEntry.make(date: Date(), snapshot: snapshot)
    }
}

/// The widget registration: small, medium, and large system sizes.
struct BudgetingWidget: Widget {
    let kind: String = "BudgetingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetTimelineProvider()) { entry in
            BudgetingWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Budget")
        .description("Show your remaining budget at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Routes each widget family to its sized view.
struct BudgetingWidgetEntryView: View {
    let entry: BudgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        case .systemLarge:  LargeWidgetView(entry: entry)
        default:            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small

private struct SmallWidgetView: View {
    let entry: BudgetEntry

    var body: some View {
        if entry.hasData {
            VStack(alignment: .leading, spacing: 4) {
                Text("Remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(formatMoney(entry.remainder))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(entry.remainder >= 0 ? Color.green : Color.red)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if entry.daysRemaining > 0 {
                    Text("\(formatMoney(entry.dailyBudget)) / day")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Link(destination: URL(string: "budgeting://add-entry")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Entry")
                    }
                    .font(.caption2)
                    .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        } else {
            EmptyWidgetView(message: "Set up your budget", buttonText: "Open App")
        }
    }
}

// MARK: - Medium

private struct MediumWidgetView: View {
    let entry: BudgetEntry

    var body: some View {
        if entry.hasData {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(formatMoney(entry.remainder))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(entry.remainder >= 0 ? Color.green : Color.red)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if entry.daysRemaining > 0 {
                        Text("\(formatMoney(entry.dailyBudget)) / day")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Link(destination: URL(string: "budgeting://add-entry")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Entry")
                        }
                        .font(.caption2)
                        .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 6) {
                    metricRow("Income", value: entry.income, color: .green)
                    metricRow("Bills", value: entry.bills, color: .orange)
                    metricRow("Expenses", value: entry.expenses, color: .red)
                    metricRow("Savings", value: entry.savings, color: .blue)
                }
                .frame(width: 140)
            }
            .padding()
        } else {
            EmptyWidgetView(message: "Set up your budget in the app", buttonText: "Open Budgeting", titleIcon: .title)
        }
    }

    private func metricRow(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatMoney(value))
                .font(.caption2)
                .monospacedDigit()
                .fontWeight(.medium)
                .foregroundStyle(value < 0 ? .red : .primary)
        }
    }
}

// MARK: - Large

private struct LargeWidgetView: View {
    let entry: BudgetEntry

    /// Fraction of income already spent on bills + expenses, clamped to 0...1.
    private var budgetUsed: Double {
        guard entry.income > 0 else { return 0 }
        let spent = entry.bills + entry.expenses
        return min(spent / entry.income, 1.0)
    }

    var body: some View {
        if entry.hasData {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(formatMoney(entry.remainder))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(entry.remainder >= 0 ? Color.green : Color.red)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        if entry.daysRemaining > 0 {
                            Text("\(formatMoney(entry.dailyBudget)) per day — \(entry.daysRemaining) days left")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Link(destination: URL(string: "budgeting://add-entry")!) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(entry.remainder >= 0 ? Color.green : Color.red)
                            .frame(width: geo.size.width * max(0, min(1, budgetUsed)))
                    }
                }
                .frame(height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                HStack(spacing: 0) {
                    metricCell("Income", value: entry.income, icon: "banknote.fill", color: .green)
                    Divider()
                    metricCell("Bills", value: entry.bills, icon: "doc.text.fill", color: .orange)
                    Divider()
                    metricCell("Expenses", value: entry.expenses, icon: "cart.fill", color: .red)
                    Divider()
                    metricCell("Savings", value: entry.savings, icon: "leaf.fill", color: .blue)
                }
            }
            .padding()
        } else {
            EmptyWidgetView(message: "Set up your budget in the app", buttonText: "Open Budgeting", titleIcon: .title)
        }
    }

    private func metricCell(_ label: String, value: Double, icon: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(formatMoney(value))
                    .font(.caption)
                    .monospacedDigit()
                    .fontWeight(.medium)
                    .foregroundStyle(value < 0 ? .red : .primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared

/// The "no data yet" placeholder shown by every size before the app writes its
/// first snapshot. `titleIcon` sizes the tray icon up for the medium/large sizes.
private struct EmptyWidgetView: View {
    let message: String
    let buttonText: String
    var titleIcon: Font = .title2

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(titleIcon)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
            Link(destination: URL(string: "budgeting://open")!) {
                Text(buttonText)
                    .font(.callout)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Formats a `Double` as a GBP currency string with a leading `£` and a `-` for
/// negatives. Lives in the widget (not in `MoneyHelper`) because the widget works
/// with `Double` values read from `UserDefaults`, whereas `MoneyHelper` works
/// with `Decimal`.
private func formatMoney(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "GBP"
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    let absValue = abs(value)
    let sign = value < 0 ? "-" : ""
    return "\(sign)\u{00A3}\(formatter.string(from: NSNumber(value: absValue)) ?? String(format: "%.2f", absValue))"
}

#Preview(as: .systemSmall) {
    BudgetingWidget()
} timeline: {
    BudgetEntry(
        date: Date(), remainder: 450.75, dailyBudget: 18.75,
        income: 3500, bills: 1250, expenses: 520,
        savings: 500, investment: 200,
        daysRemaining: 24, daysElapsed: 6, totalDays: 30,
        hasData: true, month: 6, year: 2026
    )
    BudgetEntry(
        date: Date(), remainder: -150.50, dailyBudget: -6.27,
        income: 3500, bills: 1250, expenses: 2200,
        savings: 500, investment: 200,
        daysRemaining: 24, daysElapsed: 6, totalDays: 30,
        hasData: true, month: 6, year: 2026
    )
}

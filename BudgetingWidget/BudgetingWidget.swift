import WidgetKit
import SwiftUI

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
}

struct BudgetTimelineProvider: TimelineProvider {
    private let appGroupIdentifier = "group.com.markodurasinovic.budgeting"

    func placeholder(in context: Context) -> BudgetEntry {
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

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        completion(loadFromDefaults() ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let entry = loadFromDefaults() ?? placeholder(in: context)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date().addingTimeInterval(14400)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadFromDefaults() -> BudgetEntry? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return nil }
        guard defaults.bool(forKey: "widget_hasData") else { return nil }

        let now = Date()
        return BudgetEntry(
            date: now,
            remainder: defaults.double(forKey: "widget_remainder"),
            dailyBudget: defaults.double(forKey: "widget_dailyBudget"),
            income: defaults.double(forKey: "widget_income"),
            bills: defaults.double(forKey: "widget_bills"),
            expenses: defaults.double(forKey: "widget_expenses"),
            savings: defaults.double(forKey: "widget_savings"),
            investment: defaults.double(forKey: "widget_investment"),
            daysRemaining: defaults.integer(forKey: "widget_daysRemaining"),
            daysElapsed: defaults.integer(forKey: "widget_daysElapsed"),
            totalDays: defaults.integer(forKey: "widget_totalDays"),
            hasData: defaults.bool(forKey: "widget_hasData"),
            month: defaults.integer(forKey: "widget_month"),
            year: defaults.integer(forKey: "widget_year")
        )
    }
}

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

struct BudgetingWidgetEntryView: View {
    let entry: BudgetEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

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
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Set up your budget")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link(destination: URL(string: "budgeting://open")!) {
                    Text("Open App")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}

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
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Set up your budget in the app")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Link(destination: URL(string: "budgeting://open")!) {
                    Text("Open Budgeting")
                        .font(.callout)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
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

private struct LargeWidgetView: View {
    let entry: BudgetEntry

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
                            .frame(width: geo.size.width * CGFloat(max(0, min(1, budgetUsed))))
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
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Set up your budget in the app")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Link(destination: URL(string: "budgeting://open")!) {
                    Text("Open Budgeting")
                        .font(.callout)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
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
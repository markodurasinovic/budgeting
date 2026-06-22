import Foundation

/// Centralized date formatting helpers.
///
/// Previously each view created its own `DateFormatter` with `dateFormat =
/// "MMMM yyyy"` and reconstructed a `Date` from `DateComponents`. That logic is
/// duplicated in 5 places across the app; this enum gives it a single home.
///
/// `DateFormatter` is expensive to construct, so the formatters below are
/// created once and reused. They are configured with `en_US_POSIX` for stable
/// output regardless of the user's locale, which matters because these strings
/// are used in UI headers, portfolio labels, and CSV/XLSX parsing.
public enum DateFormatting {
    /// Formats a `(month, year)` pair as a long month-and-year string,
    /// e.g. `"April 2026"`. `month` is 1–12, `year` is a full year like `2026`.
    /// Falls back to `"M/YYYY"` if the calendar cannot build the date.
    public static func monthYear(month: Int, year: Int) -> String {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else {
            return "\(month)/\(year)"
        }
        return monthYearFormatter.string(from: date)
    }

    /// Formats a `Date` as a short weekday-and-day string, e.g. `"Mon 5"`.
    /// Used by the daily-spend view's per-day rows.
    public static func weekdayDay(from date: Date) -> String {
        weekdayDayFormatter.string(from: date)
    }

    /// Formats a `Date` as a short day-and-month string, e.g. `"5 Apr"`.
    /// Used by the entry table's Date column.
    public static func dayMonth(from date: Date) -> String {
        dayMonthFormatter.string(from: date)
    }

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let weekdayDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE d"
        return f
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d MMM"
        return f
    }()
}

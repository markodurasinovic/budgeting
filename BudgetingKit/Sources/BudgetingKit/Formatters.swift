import Foundation

public enum Formatters {
    public static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    public static let shortDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEE d"
        return f
    }()

    public static let csvDateM_d_yyyy: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "M/d/yyyy"
        return f
    }()

    public static let csvDateDD_MM_yyyy: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    public static let csvDateYYYY_MM_dd: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public static func monthYearString(month: Int, year: Int) -> String {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "\(month)/\(year)" }
        return monthYear.string(from: date)
    }

    public static func shortDayString(day: Int, month: Int, year: Int) -> String {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = Calendar.current.date(from: components) else { return "Day \(day)" }
        return shortDay.string(from: date)
    }
}
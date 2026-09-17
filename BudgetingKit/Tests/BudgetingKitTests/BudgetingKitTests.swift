import Testing
@testable import BudgetingKit
import Foundation

@Suite("MoneyHelper")
struct MoneyHelperTests {
    @Test("Format whole number")
    func formatWholeNumber() {
        #expect(MoneyHelper.format(Decimal(1250)) == "£1,250")
    }

    @Test("Format decimal amount")
    func formatDecimalAmount() {
        #expect(MoneyHelper.format(Decimal(string: "1250.12")!) == "£1,250.12")
    }

    @Test("Format zero")
    func formatZero() {
        #expect(MoneyHelper.format(Decimal(0)) == "£0")
    }

    @Test("Format negative amount")
    func formatNegative() {
        #expect(MoneyHelper.format(Decimal(string: "-7.5")!) == "-£7.5")
    }

    @Test("Format small amount")
    func formatSmallAmount() {
        #expect(MoneyHelper.format(Decimal(string: "3.75")!) == "£3.75")
    }

    @Test("Parse plain integer")
    func parseInteger() {
        #expect(MoneyHelper.parse("1250") == Decimal(1250))
    }

    @Test("Parse decimal")
    func parseDecimal() {
        #expect(MoneyHelper.parse("1250.12") == Decimal(string: "1250.12"))
    }

    @Test("Parse with pound sign")
    func parseWithPoundSign() {
        #expect(MoneyHelper.parse("£1250") == Decimal(1250))
    }

    @Test("Parse negative")
    func parseNegative() {
        #expect(MoneyHelper.parse("-7.5") == Decimal(string: "-7.5"))
    }

    @Test("Parse with comma separator")
    func parseWithComma() {
        #expect(MoneyHelper.parse("1,250") == Decimal(1250))
    }

    @Test("Parse empty string returns nil")
    func parseEmpty() {
        #expect(MoneyHelper.parse("") == nil)
    }

    @Test("Parse whitespace returns nil")
    func parseWhitespace() {
        #expect(MoneyHelper.parse("   ") == nil)
    }

    @Test("Parse invalid string returns nil")
    func parseInvalid() {
        #expect(MoneyHelper.parse("abc") == nil)
    }

    @Test("Round trip: format then parse")
    func roundTrip() {
        let original = Decimal(string: "1250.12")!
        let formatted = MoneyHelper.format(original)
        let parsed = MoneyHelper.parse(formatted)
        #expect(parsed == original)
    }
}

@Suite("Entry")
struct EntryTests {
    @Test("Entry initializes with defaults")
    func entryDefaults() {
        let entry = Entry(item: "Coffee", tag: "Food", amount: Decimal(string: "3.50")!)
        #expect(entry.item == "Coffee")
        #expect(entry.tag == "Food")
        #expect(entry.amount == Decimal(string: "3.50"))
        #expect(entry.id != UUID())
    }

    @Test("Entry initializes with all parameters")
    func entryCustom() {
        let date = Date.distantPast
        let id = UUID()
        let entry = Entry(id: id, date: date, item: "Rent", tag: "Housing", amount: Decimal(1250))
        #expect(entry.id == id)
        #expect(entry.date == date)
        #expect(entry.item == "Rent")
        #expect(entry.tag == "Housing")
        #expect(entry.amount == Decimal(1250))
    }
}

@Suite("Tag")
struct TagTests {
    @Test("Tag initializes with defaults")
    func tagDefaults() {
        let tag = Tag(name: "Food")
        #expect(tag.name == "Food")
        #expect(tag.colorHex == "")
        #expect(tag.id != UUID())
    }

    @Test("Tag initializes with color")
    func tagWithColor() {
        let tag = Tag(name: "Rent", colorHex: "#4ECDC4")
        #expect(tag.name == "Rent")
        #expect(tag.colorHex == "#4ECDC4")
    }
}

@Suite("BudgetStore days")
struct BudgetStoreDaysTests {
    @Test("daysRemainingInMonth includes the current day")
    func daysRemainingIncludesToday() {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        let day = calendar.component(.day, from: now)
        let totalDays = BudgetStore.daysInMonth(month: month, year: year)

        let remaining = BudgetStore.daysRemainingInMonth(month: month, year: year)
        #expect(remaining == totalDays - day + 1)
        #expect(remaining >= 1)
    }

    @Test("daysRemainingInMonth is zero for a past month")
    func daysRemainingPastMonth() {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        let pastMonth: Int
        let pastYear: Int
        if month == 1 {
            pastMonth = 12
            pastYear = year - 1
        } else {
            pastMonth = month - 1
            pastYear = year
        }

        #expect(BudgetStore.daysRemainingInMonth(month: pastMonth, year: pastYear) == 0)
    }

    @Test("daysRemainingInMonth counts all days for a future month")
    func daysRemainingFutureMonth() {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        let futureMonth: Int
        let futureYear: Int
        if month == 12 {
            futureMonth = 1
            futureYear = year + 1
        } else {
            futureMonth = month + 1
            futureYear = year
        }

        let total = BudgetStore.daysInMonth(month: futureMonth, year: futureYear)
        #expect(BudgetStore.daysRemainingInMonth(month: futureMonth, year: futureYear) == total)
    }
}

@Suite("BudgetStore year")
struct BudgetStoreYearTests {
    private func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("completedMonthsInYear is 12 for a past year")
    func completedMonthsPastYear() {
        let pastYear = Calendar.current.component(.year, from: Date()) - 1
        #expect(BudgetStore.completedMonthsInYear(year: pastYear) == 12)
    }

    @Test("completedMonthsInYear excludes the current month")
    func completedMonthsCurrentYear() {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        #expect(BudgetStore.completedMonthsInYear(year: currentYear) == currentMonth - 1)
    }

    @Test("completedMonthsInYear is 0 for a future year")
    func completedMonthsFutureYear() {
        let futureYear = Calendar.current.component(.year, from: Date()) + 1
        #expect(BudgetStore.completedMonthsInYear(year: futureYear) == 0)
    }

    @Test("current month entries are excluded from completed-month totals but kept in monthly totals")
    func currentMonthExcluded() {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let entries = [
            Entry(date: makeDate(year: currentYear, month: currentMonth), item: "Coffee", tag: "Food", amount: Decimal(-100)),
        ]
        #expect(BudgetStore.entriesForYear(entries, year: currentYear).count == 1)
        #expect(BudgetStore.entriesForCompletedMonths(entries, year: currentYear).isEmpty)
        #expect(BudgetStore.totalForCompletedMonths(entries, year: currentYear) == Decimal(0))
        #expect(BudgetStore.averageMonthlyByTag(entries, year: currentYear).isEmpty)
        #expect(BudgetStore.totalsByMonthForYear(entries, year: currentYear)[currentMonth - 1].total == Decimal(-100))
    }

    @Test("totalForCompletedMonths sums only completed months of that year")
    func totalForCompletedMonthsFilters() {
        let year = Calendar.current.component(.year, from: Date()) - 1
        let entries = [
            Entry(date: makeDate(year: year, month: 1), item: "Coffee", tag: "Food", amount: Decimal(string: "-3.50")!),
            Entry(date: makeDate(year: year, month: 6), item: "Rent", tag: "Housing", amount: Decimal(-1200)),
            Entry(date: makeDate(year: year + 1, month: 1), item: "Rent", tag: "Housing", amount: Decimal(-1200)),
        ]
        #expect(BudgetStore.totalForCompletedMonths(entries, year: year) == Decimal(string: "-1203.50"))
        #expect(BudgetStore.entriesForCompletedMonths(entries, year: year).count == 2)
    }

    @Test("totalsByMonthForYear returns 12 dense months")
    func totalsByMonthDense() {
        let year = Calendar.current.component(.year, from: Date()) - 1
        let entries = [
            Entry(date: makeDate(year: year, month: 2), item: "Rent", tag: "Housing", amount: Decimal(-100)),
            Entry(date: makeDate(year: year, month: 2, day: 15), item: "Coffee", tag: "Food", amount: Decimal(-50)),
            Entry(date: makeDate(year: year + 1, month: 3), item: "Rent", tag: "Housing", amount: Decimal(-999)),
        ]
        let totals = BudgetStore.totalsByMonthForYear(entries, year: year)
        #expect(totals.count == 12)
        #expect(totals[0].month == 1 && totals[0].total == Decimal(0))
        #expect(totals[1].month == 2 && totals[1].total == Decimal(-150))
        #expect(totals[2].month == 3 && totals[2].total == Decimal(0))
        #expect(totals[11].month == 12 && totals[11].total == Decimal(0))
    }

    @Test("totalsByTagForCompletedMonths sums by tag sorted by absolute total")
    func totalsByTagForCompletedMonthsSorted() {
        let year = Calendar.current.component(.year, from: Date()) - 1
        let entries = [
            Entry(date: makeDate(year: year, month: 1), item: "Coffee", tag: "Food", amount: Decimal(-100)),
            Entry(date: makeDate(year: year, month: 4), item: "Rent", tag: "Housing", amount: Decimal(-500)),
            Entry(date: makeDate(year: year, month: 8), item: "Paycheck", tag: "Salary", amount: Decimal(300)),
            Entry(date: makeDate(year: year + 1, month: 1), item: "Rent", tag: "Housing", amount: Decimal(-999)),
        ]
        let totals = BudgetStore.totalsByTagForCompletedMonths(entries, year: year)
        #expect(totals.count == 3)
        #expect(totals[0].tag == "Housing" && totals[0].total == Decimal(-500))
        #expect(totals[1].tag == "Salary" && totals[1].total == Decimal(300))
        #expect(totals[2].tag == "Food" && totals[2].total == Decimal(-100))
    }

    @Test("averageMonthlySpend divides by months elapsed")
    func averageMonthlySpendPastYear() {
        let year = Calendar.current.component(.year, from: Date()) - 1
        let entries = [
            Entry(date: makeDate(year: year, month: 1), item: "Rent", tag: "Housing", amount: Decimal(-1200)),
            Entry(date: makeDate(year: year, month: 2), item: "Rent", tag: "Housing", amount: Decimal(-1200)),
            Entry(date: makeDate(year: year, month: 3), item: "Rent", tag: "Housing", amount: Decimal(-600)),
        ]
        #expect(BudgetStore.averageMonthlySpend(entries, year: year) == Decimal(-250))
    }

    @Test("averageMonthlySpend is zero for a future year")
    func averageMonthlySpendFutureYear() {
        let year = Calendar.current.component(.year, from: Date()) + 1
        let entries = [
            Entry(date: makeDate(year: year, month: 1), item: "Rent", tag: "Housing", amount: Decimal(-1200)),
        ]
        #expect(BudgetStore.averageMonthlySpend(entries, year: year) == Decimal(0))
    }

    @Test("averageMonthlyByTag divides each tag total by months elapsed")
    func averageMonthlyByTagDivides() {
        let year = Calendar.current.component(.year, from: Date()) - 1
        let entries = [
            Entry(date: makeDate(year: year, month: 1), item: "Rent", tag: "Housing", amount: Decimal(-1200)),
            Entry(date: makeDate(year: year, month: 2), item: "Rent", tag: "Housing", amount: Decimal(-1200)),
            Entry(date: makeDate(year: year, month: 1), item: "Coffee", tag: "Food", amount: Decimal(-120)),
        ]
        let averages = BudgetStore.averageMonthlyByTag(entries, year: year)
        let housing = averages.first { $0.tag == "Housing" }!
        let food = averages.first { $0.tag == "Food" }!
        #expect(housing.total == Decimal(-2400))
        #expect(housing.average == Decimal(-200))
        #expect(food.total == Decimal(-120))
        #expect(food.average == Decimal(-10))
    }

    @Test("shortMonthString returns short month names")
    func shortMonthNames() {
        #expect(Formatters.shortMonthString(month: 1) == "Jan")
        #expect(Formatters.shortMonthString(month: 12) == "Dec")
        #expect(Formatters.shortMonthString(month: 0) == "M0")
        #expect(Formatters.shortMonthString(month: 13) == "M13")
    }
}

@Suite("CSVImporter")
struct CSVImporterTests {
    @Test("Parse simple CSV rows")
    func parseSimpleRows() {
        let csv = "Date,Item,Price\n4/1/2026,Coffee,3.75\n4/2/2026,Train,8.00"
        let (rows, _) = CSVImporter.parse(content: csv)
        #expect(rows.count == 3)
        #expect(rows[1][0] == "4/1/2026")
        #expect(rows[1][1] == "Coffee")
        #expect(rows[1][2] == "3.75")
    }

    @Test("Parse quoted fields with commas")
    func parseQuotedFields() {
        let csv = "Date,Item,Price\n4/1/2026,Bills,\"1,002.00\""
        let (rows, _) = CSVImporter.parse(content: csv)
        #expect(rows.count == 2)
        #expect(rows[1][2] == "1,002.00")
    }

    @Test("Handle extra columns gracefully")
    func handleExtraColumns() {
        let csv = "Date,Item,Price,,Extra1,Extra2\n4/1/2026,Coffee,3.75,,foo,bar"
        let (rows, _) = CSVImporter.parse(content: csv)
        #expect(rows.count == 2)
        #expect(rows[1].count >= 3)
    }

    @Test("Parse item with tag in parentheses")
    func parseTagFromItem() {
        let item = "Phone (Bills)"
        let tagEnd = item.lastIndex(of: ")")!
        let tagStart = item.lastIndex(of: "(" )!
        let tag = String(item[item.index(after: tagStart)..<tagEnd])
        #expect(tag == "Bills")
    }

    @Test("Skip rows with too few columns")
    func skipShortRows() {
        let csv = "Date,Item,Price\n4/1/2026,Coffee"
        let (rows, _) = CSVImporter.parse(content: csv)
        #expect(rows.count == 2)
        #expect(rows[1].count == 2)
    }

    @Test("Empty CSV returns header only")
    func emptyCSV() {
        let csv = "Date,Item,Price"
        let (rows, _) = CSVImporter.parse(content: csv)
        #expect(rows.count == 1)
    }

    @Test("Handles CRLF line endings")
    func handleCRLF() {
        var csv = "Date,Item,Price"
        csv.append("\r\n")
        csv.append("4/1/2026,Coffee,3.75")
        let (rows, _) = CSVImporter.parse(content: csv)
        #expect(rows.count == 2)
        #expect(rows[1][1] == "Coffee")
    }
}

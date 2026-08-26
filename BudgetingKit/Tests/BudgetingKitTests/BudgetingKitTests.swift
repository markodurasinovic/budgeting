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

@Suite("BudgetStore carryover")
struct BudgetStoreCarryoverTests {
    private func date(month: Int, year: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    @Test("Carries a negative previous remainder")
    func negativePreviousRemainder() {
        let previousBudget = MonthlyBudget(month: 4, year: 2026, income: 1000)
        let entries = [Entry(date: date(month: 4, year: 2026), item: "Spending", tag: "Other", amount: 1300)]

        #expect(BudgetStore.carryover(month: 5, year: 2026, entries: entries, budgets: [previousBudget]) == Decimal(-300))
    }

    @Test("Carries a positive previous remainder")
    func positivePreviousRemainder() {
        let previousBudget = MonthlyBudget(month: 4, year: 2026, income: 1000)
        let entries = [Entry(date: date(month: 4, year: 2026), item: "Spending", tag: "Other", amount: 300)]

        #expect(BudgetStore.carryover(month: 5, year: 2026, entries: entries, budgets: [previousBudget]) == Decimal(700))
    }

    @Test("Does not carry without a configured previous budget")
    func noPreviousBudget() {
        let entries = [Entry(date: date(month: 4, year: 2026), item: "Spending", tag: "Other", amount: 1300)]

        #expect(BudgetStore.carryover(month: 5, year: 2026, entries: entries, budgets: []) == Decimal(0))
    }

    @Test("Does not carry an unconfigured previous budget")
    func unconfiguredPreviousBudget() {
        let previousBudget = MonthlyBudget(month: 4, year: 2026)
        let entries = [Entry(date: date(month: 4, year: 2026), item: "Spending", tag: "Other", amount: 1300)]

        #expect(BudgetStore.carryover(month: 5, year: 2026, entries: entries, budgets: [previousBudget]) == Decimal(0))
    }

    @Test("Looks back across the year boundary")
    func yearBoundary() {
        let previousBudget = MonthlyBudget(month: 12, year: 2025, income: 1000)
        let entries = [Entry(date: date(month: 12, year: 2025), item: "Spending", tag: "Other", amount: 1300)]

        #expect(BudgetStore.carryover(month: 1, year: 2026, entries: entries, budgets: [previousBudget]) == Decimal(-300))
    }

    @Test("Ignores entries from other months")
    func ignoresOtherMonths() {
        let previousBudget = MonthlyBudget(month: 4, year: 2026, income: 1000, savings: 1000)
        let entries = [Entry(date: date(month: 3, year: 2026), item: "Spending", tag: "Other", amount: 1300)]

        #expect(BudgetStore.carryover(month: 5, year: 2026, entries: entries, budgets: [previousBudget]) == Decimal(0))
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

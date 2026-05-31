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
import Testing
@testable import BudgetingKit
import Foundation

@Suite("MoneyHelper.format")
struct MoneyHelperFormatTests {
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

    @Test("Format plain omits the currency symbol")
    func formatPlain() {
        #expect(MoneyHelper.formatPlain(Decimal(string: "1250.12")!) == "1,250.12")
        #expect(MoneyHelper.formatPlain(Decimal(string: "-7.5")!) == "-7.5")
    }

    @Test("Format percent renders a ratio as an unsigned percentage")
    func formatPercent() {
        #expect(MoneyHelper.formatPercent(Decimal(string: "0.125")!) == "12.5%")
        #expect(MoneyHelper.formatPercent(nil) == "—")
    }
}

@Suite("MoneyHelper.parse")
struct MoneyHelperParseTests {
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

@Suite("MoneyHelper expression parsing")
struct MoneyHelperExpressionTests {
    @Test("Addition")
    func addition() {
        #expect(MoneyHelper.parse("12.50 + 3.75") == Decimal(string: "16.25"))
    }

    @Test("Operator precedence: multiplication before addition")
    func precedence() {
        #expect(MoneyHelper.parse("12.50 + 3.75 * 2") == Decimal(string: "20.00"))
    }

    @Test("Parentheses override precedence")
    func parentheses() {
        #expect(MoneyHelper.parse("(12.50 + 3.75) * 2") == Decimal(string: "32.50"))
    }

    @Test("Left-associative subtraction")
    func leftAssociative() {
        #expect(MoneyHelper.parse("10 - 2 - 3") == Decimal(5))
    }

    @Test("Division yields an exact decimal")
    func division() {
        #expect(MoneyHelper.parse("10 / 4") == Decimal(string: "2.5"))
    }

    @Test("Unary minus")
    func unaryMinus() {
        #expect(MoneyHelper.parse("-5 + 3") == Decimal(-2))
    }

    @Test("Division by zero returns nil")
    func divisionByZero() {
        #expect(MoneyHelper.parse("1 / 0") == nil)
    }

    @Test("Incomplete expression returns nil")
    func incomplete() {
        #expect(MoneyHelper.parse("12 + ") == nil)
    }

    @Test("Invalid characters return nil")
    func invalidChars() {
        #expect(MoneyHelper.parse("abc + 2") == nil)
    }

    @Test("Leading dot is normalised")
    func leadingDot() {
        #expect(MoneyHelper.parse(".5 + 1") == Decimal(string: "1.5"))
    }

    @Test("Expression with currency symbol and commas")
    func expressionWithSymbols() {
        #expect(MoneyHelper.parse("£1,250 + 3.75") == Decimal(string: "1253.75"))
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

@Suite("TagPalette")
struct TagPaletteTests {
    @Test("Stable color for a tag name across calls")
    func stableColor() {
        // The same name must map to the same hex on every call — this is the
        // bug that `String.hashValue` (randomized per launch) previously caused.
        #expect(TagPalette.hex(for: "Food") == TagPalette.hex(for: "Food"))
        #expect(TagPalette.hex(for: "food") == TagPalette.hex(for: "FOOD"))
    }

    @Test("color(at:) wraps modulo the palette size")
    func wraps() {
        let count = TagPalette.colors.count
        #expect(TagPalette.color(at: count) == TagPalette.color(at: 0))
        #expect(TagPalette.color(at: count + 5) == TagPalette.color(at: 5))
    }

    @Test("Different names can share a color but the mapping is deterministic")
    func deterministic() {
        // Spot-check two names produce valid palette entries.
        let hex1 = TagPalette.hex(for: "Coffee")
        let hex2 = TagPalette.hex(for: "Rent")
        #expect(TagPalette.colors.contains(hex1))
        #expect(TagPalette.colors.contains(hex2))
    }
}

@Suite("ImporterCore.parseItemAndTag")
struct ParseItemAndTagTests {
    @Test("Splits item and parenthetical tag")
    func split() {
        let (item, tag) = ImporterCore.parseItemAndTag("Phone (Bills)")
        #expect(item == "Phone")
        #expect(tag == "Bills")
    }

    @Test("No parentheses returns the original and nil tag")
    func noParens() {
        let (item, tag) = ImporterCore.parseItemAndTag("Coffee")
        #expect(item == "Coffee")
        #expect(tag == nil)
    }

    @Test("Unclosed paren returns the original and nil tag")
    func unclosed() {
        let (item, tag) = ImporterCore.parseItemAndTag("No closing (paren")
        #expect(item == "No closing (paren")
        #expect(tag == nil)
    }

    @Test("Empty parentheses return nil tag")
    func emptyParens() {
        let (item, tag) = ImporterCore.parseItemAndTag("Item ()")
        #expect(item == "Item ()")
        #expect(tag == nil)
    }
}

@Suite("CSVImporter.parse")
struct CSVImporterParseTests {
    @Test("Parse simple CSV rows")
    func parseSimpleRows() {
        let csv = "Date,Item,Price\n4/1/2026,Coffee,3.75\n4/2/2026,Train,8.00"
        let rows = CSVImporter.parse(content: csv)
        #expect(rows.count == 3)
        #expect(rows[1][0] == "4/1/2026")
        #expect(rows[1][1] == "Coffee")
        #expect(rows[1][2] == "3.75")
    }

    @Test("Parse quoted fields with commas")
    func parseQuotedFields() {
        let csv = "Date,Item,Price\n4/1/2026,Bills,\"1,002.00\""
        let rows = CSVImporter.parse(content: csv)
        #expect(rows.count == 2)
        #expect(rows[1][2] == "1,002.00")
    }

    @Test("Handle extra columns gracefully")
    func handleExtraColumns() {
        let csv = "Date,Item,Price,,Extra1,Extra2\n4/1/2026,Coffee,3.75,,foo,bar"
        let rows = CSVImporter.parse(content: csv)
        #expect(rows.count == 2)
        #expect(rows[1].count >= 3)
    }

    @Test("Skip rows with too few columns")
    func skipShortRows() {
        let csv = "Date,Item,Price\n4/1/2026,Coffee"
        let rows = CSVImporter.parse(content: csv)
        #expect(rows.count == 2)
        #expect(rows[1].count == 2)
    }

    @Test("Empty CSV returns header only")
    func emptyCSV() {
        let csv = "Date,Item,Price"
        let rows = CSVImporter.parse(content: csv)
        #expect(rows.count == 1)
    }

    @Test("Handles CRLF line endings")
    func handleCRLF() {
        var csv = "Date,Item,Price"
        csv.append("\r\n")
        csv.append("4/1/2026,Coffee,3.75")
        let rows = CSVImporter.parse(content: csv)
        #expect(rows.count == 2)
        #expect(rows[1][1] == "Coffee")
    }
}

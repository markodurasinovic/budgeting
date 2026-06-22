# Budgeting

A native budgeting app for macOS, built with SwiftUI and SwiftData.

## Features

- Record income and expenses with tags
- Track per-tag spending with monthly breakdowns
- Quick entry input with date picker (defaults to today); amount field accepts
  arithmetic (`12.50 + 3.75 * 2`)
- A macOS widget showing the month's remainder and daily budget, with a deep
  link back into the app to add an entry
- Portfolio snapshots (investments + debts) with month-over-month deltas
- Import entries and budget fields from CSV and XLSX files
- Decimal amounts (£ GBP)

## Tech Stack

- **Language:** Swift 6
- **UI:** SwiftUI
- **Persistence:** SwiftData (local SQLite; CloudKit sync is currently disabled)
- **macOS:** 14.0+

## Project Structure

```
BudgetingKit/         Shared Swift package (models, stores, importers, helpers)
  Sources/BudgetingKit/
    Entry.swift             @Model — a single income/expense line item
    Tag.swift               @Model — tag registry (name + color)
    MonthlyBudget.swift     @Model — per-month income/bills/savings/investment
    PortfolioSnapshot.swift @Model — per-month investment balances
    DebtSnapshot.swift      @Model — per-month debt balances
    BudgetingContainer.swift  ModelContainer factory + preview seed data
    BudgetStore.swift          Stateless data ops (entry CRUD, tag colors, calendar math, budget metrics)
    PortfolioStore.swift       Stateless portfolio ops (snapshots, deltas, formatting)
    MoneyHelper.swift          £ formatting + parsing (with a built-in expression parser)
    ColorHex.swift             Color(hex:) + the shared TagPalette
    DateFormatting.swift       Centralized month/year/weekday formatters
    DecimalExtensions.swift    Decimal → Double / CGFloat conversions
    ArrayExtensions.swift      Array[safe:] + String.nilIfEmpty
    WidgetData.swift           App↔widget bridge (App Group UserDefaults read/write)
    CSVImporter.swift          CSV tokenizer + row import
    XLSXImporter.swift         CoreXLSX cell reader + row import
    ImporterCore.swift         Shared import logic (classification, budget application, ImportResult)
BudgetingMac/         macOS app target
  Views/
    MainContentView.swift    Top-level NavigationSplitView + sheets + widget refresh
    SidebarView.swift        Month navigation + view filters + tag list
    SidebarSelection.swift   Enum for the sidebar destinations (replaces magic strings)
    DetailView.swift         Entries table + header + summary bar
    MacCategoryBreakdownView.swift   Categories analytics
    MacDailySpendView.swift          Daily-spend analytics
    MacPortfolioView.swift           Portfolio analytics
    MacAddEditEntryView.swift        Add/edit entry sheet
    MacBudgetEditView.swift          Edit monthly budget sheet
    MacPortfolioEditView.swift       Edit portfolio snapshot sheet
    MacCSVImportView.swift           CSV/XLSX import sheet + result summary
BudgetingWidget/      macOS widget extension
  BudgetingWidget.swift         Small/Medium/Large widget views + timeline provider
  BudgetingWidgetBundle.swift   Widget bundle entry point
project.yml           XcodeGen project spec
install.sh            Build + install to /Applications (ad-hoc signed)
```

## Architecture notes

- **SwiftData models** are `@Model final public class`es in `BudgetingKit`. The
  `@Model` macro generates persistence wiring; `final public` makes them
  non-overrideable and visible to the app targets that import the package.
- **Stateless stores** (`BudgetStore`, `PortfolioStore`, `ImporterCore`) are
  `enum`s with no cases — used as namespaces. They take a `ModelContext`
  explicitly so they're testable and work against any container.
- **Views** use `@Query` to observe SwiftData, `@State`/`@Binding` for local UI
  state, and `.sheet` for modals. The sidebar drives a `SidebarSelection` enum
  that routes to the right detail view in `MainContentView`.
- **Widget** runs in a separate process and can't see the database, so the app
  writes a monthly summary to a shared App Group `UserDefaults` via
  `WidgetData.write`, and the widget reads it via `WidgetData.read`.

## Getting Started

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `Budgeting.xcodeproj` in Xcode
4. Select your team in Signing & Capabilities for both targets
5. Build and run

See `WIDGET_SETUP.md` for the one manual step required to share data between the
app and the widget (registering the App Group).

## Development

This project follows the [Karpathy agent skills](https://github.com/multica-ai/andrej-karpathy-skills) principles:

1. **Think Before Coding** — state assumptions, present tradeoffs, ask when uncertain
2. **Simplicity First** — minimum code that solves the problem, nothing speculative
3. **Surgical Changes** — touch only what you must, match existing style
4. **Goal-Driven Execution** — define success criteria, verify before moving on

## Tests

```bash
cd BudgetingKit && swift test
```

Covers `MoneyHelper` formatting/parsing (including the expression parser), the
data models, `TagPalette` color stability, `ImporterCore.parseItemAndTag`, and
the CSV tokenizer.

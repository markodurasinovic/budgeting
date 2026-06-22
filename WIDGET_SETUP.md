# Budget Widget Setup Guide

## Architecture

The widget shares data with the main app via **App Group UserDefaults** (`group.com.markodurasinovic.budgeting`). The main app writes budget summary data to UserDefaults whenever entries change, and the widget reads from those same UserDefaults to display the remainder.

- **Data flow**: App → `BudgetingContainer.writeWidgetData()` → App Group UserDefaults → Widget reads on timeline refresh
- **Deep link**: The "Add Entry" button on the widget opens `budgeting://add-entry`, which the app handles via `.onOpenURL` to present the add-entry sheet
- **Refresh**: Widget refreshes every 4 hours automatically, plus immediately after adding/editing entries or importing CSV

## Required: Register App Group in Xcode

This is the **only manual step** — Xcode needs to generate provisioning profiles that include the App Group entitlement.

1. Open `Budgeting.xcodeproj` in Xcode
2. Select the **BudgetingMac** target → Signing & Capabilities tab
3. Click **+ Capability** → add **App Groups**
4. Add the group: `group.com.markodurasinovic.budgeting`
5. Select the **BudgetingWidget** target → Signing & Capabilities tab
6. Click **+ Capability** → add **App Groups**
7. Add the same group: `group.com.markodurasinovic.budgeting`
8. Xcode will generate/update the provisioning profiles automatically

After this, both the app and widget will be able to share UserDefaults data.

## Widget Sizes

| Size | Content |
|------|---------|
| **Small** | Remainder value, daily budget, "Add Entry" link |
| **Medium** | Remainder + daily budget (left), Income/Bills/Expenses/Savings metrics (right), "Add Entry" link |
| **Large** | Remainder + daily budget + days left, budget usage progress bar, Income/Bills/Expenses/Savings row, "Add Entry" button |

## Adding the Widget

After building and installing the app:

1. Open **Notification Center** (click the date/time in the menu bar, or two-finger swipe from right edge of trackpad)
2. Scroll down and click **Edit Widgets**
3. Search for **Budget** or **Budgeting**
4. Drag the widget to your preferred size/position
5. Click Done

## File Reference

| File | Purpose |
|------|---------|
| `BudgetingWidget/BudgetingWidgetBundle.swift` | Widget bundle entry point |
| `BudgetingWidget/BudgetingWidget.swift` | Widget UI (3 sizes) + TimelineProvider |
| `BudgetingWidget/BudgetingWidget.entitlements` | App Group entitlement |
| `BudgetingMac/BudgetingMac.entitlements` | App Group entitlement (main app) |
| `BudgetingKit/Sources/BudgetingKit/BudgetingContainer.swift` | `writeWidgetData()` — writes budget data to shared UserDefaults |
| `BudgetingMac/BudgetingMacApp.swift` | Deep link handler (`budgeting://add-entry`) |
| `BudgetingMac/Views/MainContentView.swift` | Widget data write + refresh triggers |
| `project.yml` | XcodeGen config — widget target + URL scheme |

## UserDefaults Keys

Written by `BudgetingContainer.writeWidgetData()`, read by `BudgetTimelineProvider`:

| Key | Type | Description |
|-----|------|-------------|
| `widget_remainder` | Double | Current month's remainder |
| `widget_dailyBudget` | Double | Remainder ÷ days remaining |
| `widget_income` | Double | Monthly income |
| `widget_bills` | Double | Monthly bills |
| `widget_expenses` | Double | Total expenses this month |
| `widget_savings` | Double | Monthly savings allocation |
| `widget_investment` | Double | Monthly investment allocation |
| `widget_daysRemaining` | Int | Days left in the month |
| `widget_daysElapsed` | Int | Days elapsed in the month |
| `widget_totalDays` | Int | Total days in the month |
| `widget_hasData` | Bool | Whether budget data exists |
| `widget_month` | Int | Current month number |
| `widget_year` | Int | Current year |

## Building & Installing

```bash
./install.sh
```

This builds both the app and widget extension, copies them to `/Applications`, and ad-hoc signs the bundle. The widget extension is embedded inside `BudgetingMac.app/Contents/Plugins/BudgetingWidget.appex`.

## Troubleshooting

- **Widget shows "Set up your budget"**: Open the app first — it writes data to the shared UserDefaults on launch. If the app has data but the widget still shows empty, check that the App Group is properly registered in Xcode.
- **"Add Entry" link doesn't work**: Ensure the app is running. Deep links require the app to be open on macOS.
- **Widget data is stale**: The widget refreshes every 4 hours by default. It also refreshes when you add/edit/delete entries or import a CSV. You can force a refresh by editing any entry.
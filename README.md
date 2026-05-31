# Budgeting

A native budgeting app for iOS and macOS, built with SwiftUI and SwiftData.

## Features

- Record income and expenses with tags
- Track per-tag spending with monthly breakdowns
- Quick entry input with date picker (defaults to today)
- iCloud sync between iOS and macOS via CloudKit
- Decimal amounts (£ GBP)

## Tech Stack

- **Language:** Swift 6
- **UI:** SwiftUI (native per platform)
- **Persistence:** SwiftData with CloudKit sync
- **iOS:** 17.0+
- **macOS:** 14.0+

## Project Structure

```
BudgetingKit/         Shared Swift Package (models, view models, utilities)
BudgetingiOS/         iOS app target
BudgetingMac/         macOS app target
project.yml           XcodeGen project spec
```

## Getting Started

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `Budgeting.xcodeproj` in Xcode
4. Select your team in Signing & Capabilities for both targets
5. Build and run

## Development

This project follows the [Karpathy agent skills](https://github.com/multica-ai/andrej-karpathy-skills) principles:

1. **Think Before Coding** — state assumptions, present tradeoffs, ask when uncertain
2. **Simplicity First** — minimum code that solves the problem, nothing speculative
3. **Surgical Changes** — touch only what you must, match existing style
4. **Goal-Driven Execution** — define success criteria, verify before moving on
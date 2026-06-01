// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BudgetingKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BudgetingKit",
            targets: ["BudgetingKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.2")
    ],
    targets: [
        .target(
            name: "BudgetingKit",
            dependencies: ["CoreXLSX"],
            path: "Sources"
        ),
        .testTarget(
            name: "BudgetingKitTests",
            dependencies: ["BudgetingKit"],
            path: "Tests"
        )
    ]
)
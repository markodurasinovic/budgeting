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
    targets: [
        .target(
            name: "BudgetingKit",
            path: "Sources"
        ),
        .testTarget(
            name: "BudgetingKitTests",
            dependencies: ["BudgetingKit"],
            path: "Tests"
        )
    ]
)
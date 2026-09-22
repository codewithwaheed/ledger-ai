// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LedgerReports",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "LedgerReports", targets: ["LedgerReports"])],
    dependencies: [
        .package(path: "../LedgerCore"),
    ],
    targets: [
        .target(name: "LedgerReports", dependencies: [
            .product(name: "LedgerCore", package: "LedgerCore"),
        ])
    ]
)

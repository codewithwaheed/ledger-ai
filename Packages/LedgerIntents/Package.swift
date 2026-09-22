// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LedgerIntents",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "LedgerIntents", targets: ["LedgerIntents"])],
    dependencies: [
        .package(path: "../LedgerCore"),
        .package(path: "../LedgerParsing"),
        .package(path: "../LedgerAI"),
    ],
    targets: [
        .target(name: "LedgerIntents", dependencies: [
            .product(name: "LedgerCore", package: "LedgerCore"),
            .product(name: "LedgerParsing", package: "LedgerParsing"),
            .product(name: "LedgerAI", package: "LedgerAI"),
        ])
    ]
)

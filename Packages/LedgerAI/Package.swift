// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LedgerAI",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "LedgerAI", targets: ["LedgerAI"])],
    dependencies: [
        .package(path: "../LedgerCore"),
        .package(path: "../LedgerParsing"),
    ],
    targets: [
        .target(name: "LedgerAI", dependencies: [
            .product(name: "LedgerCore", package: "LedgerCore"),
            .product(name: "LedgerParsing", package: "LedgerParsing"),
        ])
    ]
)

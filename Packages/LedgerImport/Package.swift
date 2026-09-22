// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LedgerImport",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "LedgerImport", targets: ["LedgerImport"])],
    dependencies: [
        .package(path: "../LedgerCore"),
        .package(path: "../LedgerParsing"),
    ],
    targets: [
        .target(name: "LedgerImport", dependencies: [
            .product(name: "LedgerCore", package: "LedgerCore"),
            .product(name: "LedgerParsing", package: "LedgerParsing"),
        ])
    ]
)

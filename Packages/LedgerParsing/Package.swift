// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LedgerParsing",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "LedgerParsing", targets: ["LedgerParsing"])],
    dependencies: [
        .package(path: "../LedgerCore"),
    ],
    targets: [
        .target(name: "LedgerParsing", dependencies: [
            .product(name: "LedgerCore", package: "LedgerCore"),
        ]),
        .testTarget(name: "LedgerParsingTests", dependencies: ["LedgerParsing"], resources: [.copy("Fixtures")])
    ]
)

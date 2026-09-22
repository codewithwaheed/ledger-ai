// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LedgerCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "LedgerCore", targets: ["LedgerCore"])],
    targets: [
        .target(name: "LedgerCore")
    ]
)

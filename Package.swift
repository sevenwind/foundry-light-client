// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FoundryLite",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "FoundryLite", path: "Sources/FoundryLite")
    ]
)

// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TypeCraft",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "HumanTyper",
            path: "Sources/HumanTyper"
        )
    ]
)



// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhosThere",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "WhosThere",
            path: "Sources"
        )
    ]
)


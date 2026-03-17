// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NBA-Live",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "NBALiveApp",
            targets: ["NBALiveApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "NBALiveApp",
            path: "Sources/NBALiveApp"
        ),
        .testTarget(
            name: "NBALiveAppTests",
            dependencies: ["NBALiveApp"],
            path: "Tests/NBALiveAppTests"
        )
    ]
)

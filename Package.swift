// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpawnWatch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SpawnWatch", targets: ["SpawnWatch"]),
        .library(name: "SpawnWatchCore", targets: ["SpawnWatchCore"]),
    ],
    targets: [
        .executableTarget(
            name: "SpawnWatch",
            dependencies: ["SpawnWatchCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
        .target(
            name: "SpawnWatchCore",
            linkerSettings: [
                .linkedFramework("Security"),
            ]
        ),
        .testTarget(
            name: "SpawnWatchCoreTests",
            dependencies: ["SpawnWatchCore"]
        ),
        .testTarget(
            name: "SpawnWatchTests",
            dependencies: ["SpawnWatch", "SpawnWatchCore"]
        ),
    ]
)

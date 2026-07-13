// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "load-spinner",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "LoadSpinnerCore"
        ),
        .executableTarget(
            name: "load-spinner",
            dependencies: ["LoadSpinnerCore"],
            resources: []
        ),
        .testTarget(
            name: "LoadSpinnerCoreTests",
            dependencies: ["LoadSpinnerCore"]
        ),
    ]
)

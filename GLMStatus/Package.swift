// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GLMStatus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GLMStatus",
            path: "Sources/GLMStatus"
        ),
        .testTarget(
            name: "GLMStatusTests",
            dependencies: ["GLMStatus"],
            path: "Tests/GLMStatusTests"
        ),
    ]
)

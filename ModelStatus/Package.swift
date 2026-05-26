// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ModelStatus",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "ModelStatusKit",
            path: "Sources/ModelStatus",
            exclude: ["ModelStatusApp.swift"]
        ),
        .executableTarget(
            name: "ModelStatus",
            dependencies: ["ModelStatusKit"],
            path: "Sources/ModelStatus",
            exclude: [
                "Models",
                "Services",
                "Views",
            ],
            sources: ["ModelStatusApp.swift"]
        ),
        .testTarget(
            name: "ModelStatusTests",
            dependencies: ["ModelStatusKit"],
            path: "Tests/ModelStatusTests"
        ),
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "llm-quota-monitor",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "LLMQuotaMonitorKit",
            path: "Sources/LLMQuotaMonitor",
            exclude: ["LLMQuotaMonitorApp.swift"]
        ),
        .executableTarget(
            name: "LLMQuotaMonitor",
            dependencies: ["LLMQuotaMonitorKit"],
            path: "Sources/LLMQuotaMonitor",
            exclude: [
                "Models",
                "Services",
                "Views",
            ],
            sources: ["LLMQuotaMonitorApp.swift"]
        ),
        .executableTarget(
            name: "LLMQuotaMonitorTests",
            dependencies: ["LLMQuotaMonitorKit"],
            path: "Tests/LLMQuotaMonitorTests"
        ),
    ]
)

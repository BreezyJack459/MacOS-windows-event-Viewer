// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WinEventLogViewer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "EventLogCore",
            targets: ["EventLogCore"]
        ),
        .executable(
            name: "WinEventLogViewer",
            targets: ["WinEventLogViewer"]
        )
    ],
    targets: [
        .target(
            name: "EventLogCore"
        ),
        .executableTarget(
            name: "WinEventLogViewer",
            dependencies: ["EventLogCore"]
        ),
        .testTarget(
            name: "EventLogCoreTests",
            dependencies: ["EventLogCore"]
        )
    ]
)

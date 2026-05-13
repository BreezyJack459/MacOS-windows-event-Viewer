// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WinEventLogViewer",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "EventLogCore",
            targets: ["EventLogCore"]
        ),
        // SwiftPM builds the command-line executable. The release script wraps this
        // binary into a macOS .app bundle and then packages it as a .dmg.
        .executable(
            name: "WinEventLogViewer",
            targets: ["WinEventLogViewer"]
        )
    ],
    targets: [
        .target(
            name: "EventLogCore"
        ),
        // Keep app assets under Sources/WinEventLogViewer/Resources so they are
        // available when the executable is wrapped into the release .app bundle.
        .executableTarget(
            name: "WinEventLogViewer",
            dependencies: ["EventLogCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EventLogCoreTests",
            dependencies: ["EventLogCore"]
        )
    ]
)

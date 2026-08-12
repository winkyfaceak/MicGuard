// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MicGuard",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic + the Core Audio HAL wrapper. Kept separate from the app
        // target so the selection rules can be unit tested without a GUI.
        .target(name: "MicGuardCore"),

        // The menu bar app itself.
        .executableTarget(
            name: "MicGuard",
            dependencies: ["MicGuardCore"]
        ),

        // Assertions over MicGuardCore, plus a live device dump.
        //
        // Deliberately an executable rather than a `.testTarget`: Command Line
        // Tools ships neither swift-testing nor XCTest, so `swift test` cannot
        // run without a full Xcode install. Run it with `make test`.
        .executableTarget(
            name: "MicGuardCheck",
            dependencies: ["MicGuardCore"]
        ),
    ]
)

// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "InPlaceTapSpike",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "InPlaceTapSpike",
            path: "Sources/InPlaceTapSpike",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        )
    ]
)

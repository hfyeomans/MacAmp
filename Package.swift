// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacAmp",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "MacAmp", targets: ["MacAmp"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "MacAmp",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "MacAmpApp",
            exclude: [
                "Info.plist",
                "MacAmp.entitlements"
            ],
            resources: [
                .process("Skins"),
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "MacAmpTests",
            dependencies: ["MacAmp"],
            path: "Tests/MacAmpTests"
        )
    ]
)

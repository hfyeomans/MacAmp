// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacAmp",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "MacAmpApp", targets: ["MacAmpApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "MacAmpApp",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "MacAmpApp",
            resources: [
                .process("Skins")
            ]
        )
    ]
)

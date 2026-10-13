// swift-tools-version:5.10
// 纯逻辑核心包：地图、状态、命令、运输求解与经济步进。
// 不依赖 UIKit / SpriteKit / SwiftUI，可在 macOS、iOS 与 Linux（CI）上运行测试。
import PackageDescription

let package = Package(
    name: "AntKingdomCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AntKingdomCore", targets: ["AntKingdomCore"]),
        .executable(name: "ak-sim", targets: ["ak-sim"]),
    ],
    targets: [
        .target(name: "AntKingdomCore"),
        .executableTarget(name: "ak-sim", dependencies: ["AntKingdomCore"]),
        .testTarget(name: "AntKingdomCoreTests", dependencies: ["AntKingdomCore"]),
    ]
)

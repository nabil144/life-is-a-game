// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LifeEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LifeEngine", targets: ["LifeEngine"]),
    ],
    targets: [
        .target(name: "LifeEngine"),
        .testTarget(name: "LifeEngineTests", dependencies: ["LifeEngine"]),
    ]
)

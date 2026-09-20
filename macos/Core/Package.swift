// swift-tools-version: 6.2
import PackageDescription

// Arayüzsüz çekirdek: modeller, API istemcisi, realtime, gün yardımcıları.
// Uygulamadan bağımsız derlenir ve `swift test` ile sınanır.
let package = Package(
    name: "TaskTrackerCore",
    platforms: [.macOS(.v26)],
    products: [.library(name: "TaskTrackerCore", targets: ["TaskTrackerCore"])],
    targets: [
        .target(name: "TaskTrackerCore"),
        .testTarget(name: "TaskTrackerCoreTests", dependencies: ["TaskTrackerCore"]),
    ]
)

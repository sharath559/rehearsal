// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "Rehearsal",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "RehearsalCore", targets: ["RehearsalCore"]),
        .executable(name: "rehearsal-demo", targets: ["RehearsalDemo"]),
        .executable(name: "RehearsalApp", targets: ["RehearsalApp"])
    ],
    targets: [
        .target(name: "RehearsalCore"),
        .executableTarget(name: "RehearsalDemo", dependencies: ["RehearsalCore"]),
        .executableTarget(name: "RehearsalApp", dependencies: ["RehearsalCore"]),
        .testTarget(name: "RehearsalCoreTests", dependencies: ["RehearsalCore"])
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let v5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "GitBeat",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "GitBeatCore", swiftSettings: v5),
        .executableTarget(name: "GitBeat", dependencies: ["GitBeatCore"], swiftSettings: v5),
        .executableTarget(name: "GitBeatChecks", dependencies: ["GitBeatCore"], path: "Tests/GitBeatChecks", swiftSettings: v5),
    ]
)

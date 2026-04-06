// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LaTeXCockpitModules",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Shared", targets: ["Shared"]),
        .executable(name: "LaTeXCockpitMac", targets: ["MacApp"])
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: [],
            path: "Core/Sources"
        ),
        .target(
            name: "Shared",
            dependencies: ["Core"],
            path: "Shared/Sources"
        ),
        .executableTarget(
            name: "MacApp",
            dependencies: ["Core", "Shared"],
            path: "Apps/MacApp/Sources"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Core/Tests"
        )
    ]
)

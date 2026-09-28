// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Halo",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Halo", targets: ["Halo"]),
    ],
    targets: [
        .executableTarget(
            name: "Halo",
            path: "Sources/Halo"
        ),
        .testTarget(
            name: "HaloTests",
            dependencies: ["Halo"],
            path: "Tests/HaloTests"
        ),
    ]
)

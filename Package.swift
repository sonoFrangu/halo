// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Halo",
    // String form instead of `.v26`: the `.v26` constant is missing from some
    // Command Line Tools releases of PackageDescription.
    platforms: [.macOS("26.0")],
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

// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "swift-persistence",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "Persistence",
            targets: ["Persistence"]
        )
    ],
    targets: [
        .target(
            name: "Persistence"
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: [
                .target(name: "Persistence")
            ]
        ),
    ]
)

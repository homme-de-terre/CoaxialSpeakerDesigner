// swift-tools-version: 5.5
import PackageDescription

let package = Package(
    name: "HP35Native",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "HP35Native", targets: ["HP35Native"])
    ],
    targets: [
        .executableTarget(
            name: "HP35Native",
            path: "Sources"
        )
    ]
)

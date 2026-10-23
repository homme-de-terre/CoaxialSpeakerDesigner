// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CoaxialSpeakerDesigner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CoaxialSpeakerDesigner",
            targets: ["CoaxialSpeakerDesigner"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CoaxialSpeakerDesigner",
            dependencies: [],
            path: "Sources/CoaxialSpeakerDesigner"
        ),
        .testTarget(
            name: "CoaxialSpeakerDesignerTests",
            dependencies: ["CoaxialSpeakerDesigner"],
            path: "Tests/CoaxialSpeakerDesignerTests"
        )
    ]
)

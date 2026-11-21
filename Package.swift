// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NgaemBook",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NgaemBook", targets: ["NgaemBook"]),
    ],
    targets: [
        .target(
            name: "LidAngleCore",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "NgaemBook",
            dependencies: ["LidAngleCore"],
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("ServiceManagement")]
        ),
        .testTarget(
            name: "LidAngleCoreTests",
            dependencies: ["LidAngleCore"]
        ),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Slip",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Slip", targets: ["Slip"])],
    targets: [
        .target(name: "SlipCore"),
        .executableTarget(name: "Slip", dependencies: ["SlipCore"]),
        .testTarget(name: "SlipCoreTests", dependencies: ["SlipCore"]),
        .testTarget(name: "SlipEditorTests", dependencies: ["Slip", "SlipCore"])
    ],
    swiftLanguageModes: [.v6]
)

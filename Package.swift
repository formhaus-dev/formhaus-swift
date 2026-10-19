// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Formhaus",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "FormhausCore", targets: ["FormhausCore"])
    ],
    targets: [
        .target(name: "FormhausCore"),
        .testTarget(
            name: "FormhausCoreTests",
            dependencies: ["FormhausCore"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)

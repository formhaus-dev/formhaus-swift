// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Formhaus",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FormhausCore", targets: ["FormhausCore"]),
        .library(name: "FormhausUI", targets: ["FormhausUI"]),
    ],
    targets: [
        .target(name: "FormhausCore"),
        .target(name: "FormhausUI", dependencies: ["FormhausCore"]),
        .testTarget(
            name: "FormhausCoreTests",
            dependencies: ["FormhausCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "FormhausUITests", dependencies: ["FormhausUI", "FormhausCore"]),
    ],
    swiftLanguageModes: [.v6]
)

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Formhaus",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FormhausCore", targets: ["FormhausCore"]),
        .library(name: "FormhausUI", targets: ["FormhausUI"]),
        .library(name: "FormhausResearch", targets: ["FormhausResearch"]),
    ],
    targets: [
        .target(name: "FormhausCore", resources: [.copy("Resources")]),
        .target(name: "FormhausUI", dependencies: ["FormhausCore"]),
        .target(name: "FormhausResearch", dependencies: ["FormhausCore"]),
        .testTarget(
            name: "FormhausCoreTests",
            dependencies: ["FormhausCore", "FormhausResearch"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "FormhausUITests",
            dependencies: ["FormhausUI", "FormhausCore", "FormhausResearch"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)

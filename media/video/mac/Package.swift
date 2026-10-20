// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RenderMac",
    platforms: [.macOS(.v14)],
    dependencies: [.package(name: "Formhaus", path: "../../..")],
    targets: [
        .executableTarget(
            name: "RenderMac",
            dependencies: [.product(name: "FormhausUI", package: "Formhaus"), .product(name: "FormhausCore", package: "Formhaus")]
        )
    ],
    swiftLanguageModes: [.v6]
)

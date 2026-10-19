// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FormhausBenchmarks",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.38.0"),
    ],
    targets: [
        .executableTarget(
            name: "RegexBenchmarks",
            dependencies: [
                .product(name: "FormhausCore", package: "formhaus-swift"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/RegexBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "package-benchmark")]
        )
    ]
)

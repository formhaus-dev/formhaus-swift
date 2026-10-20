// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FormhausBenchmarks",
    platforms: [.macOS(.v14)],
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
        ),
        .executableTarget(
            name: "RecallBenchmarks",
            dependencies: [
                .product(name: "FormhausCore", package: "formhaus-swift"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/RecallBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "package-benchmark")]
        ),
        .executableTarget(
            name: "RendererBenchmarks",
            dependencies: [
                .product(name: "FormhausCore", package: "formhaus-swift"),
                .product(name: "FormhausUI", package: "formhaus-swift"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/RendererBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "package-benchmark")]
        ),
    ]
)

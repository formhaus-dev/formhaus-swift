import AppKit
import Benchmark
import FormhausCore
import FormhausUI
import SwiftUI

private let pictures: JSONValue = [
    "id": "bench", "title": "Bench", "submit": ["label": "Send"],
    "fields": [
        [
            "key": "big", "type": "radio", "label": "Big",
            "options": .array(
                (0..<3000).map { index in
                    ["value": .string("v\(index)"), "label": .string("Label \(index)"), "image": .string("https://example.invalid/\(index).png")]
                }),
        ]
    ],
]

@MainActor
private func pictureModel() -> FormModel {
    guard let definition = try? FormDefinition(json: pictures) else { fatalError("invalid benchmark definition") }
    return FormModel(definition: definition) { _, _ in nil }
}

@MainActor
private func hosted(_ model: FormModel) -> NSView {
    _ = NSApplication.shared
    let host = NSHostingView(rootView: ScrollView { FormhausFormContent(model: model) }.frame(width: 360, height: 900))
    host.frame = CGRect(x: 0, y: 0, width: 360, height: 900)
    settle(host)
    return host
}

@MainActor
private func settle(_ host: NSView) {
    for _ in 0..<3 {
        RunLoop.main.run(until: Date())
        host.layoutSubtreeIfNeeded()
        host.display()
    }
}

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(metrics: [.wallClock], maxDuration: .seconds(5), maxIterations: 20)
    Benchmark("render 3000 picture options") { _ in
        await MainActor.run { blackHole(hosted(pictureModel())) }
    }
    Benchmark("select one of 3000 picture options") { measured in
        nonisolated(unsafe) let benchmark = measured
        await MainActor.run {
            let model = pictureModel()
            let host = hosted(model)
            benchmark.startMeasurement()
            for index in benchmark.scaledIterations {
                model.setValue(.string("v\(index % 2 + 5)"), forKey: "big")
                settle(host)
            }
            benchmark.stopMeasurement()
        }
    }
}

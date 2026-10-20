import Benchmark
@_spi(Renderer) import FormhausCore

private let definition: JSONValue = [
    "formatVersion": "1.5", "id": "bench", "submit": ["label": "Send"],
    "steps": [
        [
            "id": "about", "title": "About you",
            "fields": [
                ["key": "name", "type": "text", "label": "Name"],
                ["key": "start", "type": "date", "label": "Start"],
                ["key": "budget", "type": "number", "label": "Budget"],
                [
                    "key": "plan", "type": "multiselect", "label": "Plan",
                    "options": [["value": "pro", "label": "Pro"], ["value": "team", "label": "Team"]],
                ],
            ],
        ],
        [
            "id": "review", "title": "Review",
            "fields": [
                ["key": "plain", "type": "text", "label": "Anything to add?"],
                ["key": "summary", "type": "text", "label": "{{name}}, {{plan}} from {{start}} for {{budget}}"],
            ],
        ],
    ],
]

private let values: JSONObject = ["name": "Ada  Lovelace", "start": "2027-06-14", "budget": 12500, "plan": ["pro", "team"]]

private let stored: RecallFormatFn = { answer, _, _ in answer.stored }

@MainActor private var engines: [Int: FormEngine] = [:]

@MainActor
private func prepare(_ id: Int, _ format: RecallFormatFn?) throws {
    if engines[id] == nil {
        engines[id] = try FormEngine(definition: definition, values: values, options: FormEngineOptions(formatRecall: format))
    }
}

@MainActor
private func recall(_ id: Int, field index: Int, _ iterations: Range<Int>) {
    guard let engine = engines[id], let field = engine.definition.steps?[1].fields[index].field else { return }
    for _ in iterations { blackHole(engine.recalled(field)) }
}

private func measure(_ benchmark: Benchmark, _ id: Int, _ format: RecallFormatFn?, field: Int) async throws {
    let iterations = benchmark.scaledIterations
    try await prepare(id, format)
    benchmark.startMeasurement()
    await recall(id, field: field, iterations)
    benchmark.stopMeasurement()
}

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(metrics: [.wallClock, .throughput, .mallocCountTotal], maxDuration: .seconds(2))
    Benchmark("recall text without tokens", configuration: .init(scalingFactor: .kilo)) { benchmark in
        try await measure(benchmark, 0, nil, field: 0)
    }
    Benchmark("recall four answers as stored", configuration: .init(scalingFactor: .kilo)) { benchmark in
        try await measure(benchmark, 1, stored, field: 1)
    }
    Benchmark("recall four answers formatted", configuration: .init(scalingFactor: .kilo)) { benchmark in
        try await measure(benchmark, 2, nil, field: 1)
    }
}

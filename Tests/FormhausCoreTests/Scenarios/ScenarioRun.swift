import FormhausCore

typealias Outcome = Result<JSONValue?, any Error>

@MainActor
final class ScenarioRun {
    let file: ScenarioFile
    let scenario: JSONObject
    let engine: FormEngine
    let script: Script
    let log: EventLog
    var failures: [String]
    var pending: [(label: String, task: Task<Void, Never>, done: Flag)] = []

    init(_ file: ScenarioFile, _ scenario: JSONObject) throws {
        let hooks = ScenarioHooks(scenario: scenario, script: Script(), log: EventLog())
        self.file = file
        self.scenario = scenario
        script = hooks.script
        log = hooks.log
        failures = hooks.unknownNames.map { "unknown hook \($0)" }
        let values = scenario["values"]?.objectValue ?? JSONObject()
        engine = FormEngine(definition: try file.runtime(scenario), values: values, options: hooks.options())
    }

    func handler(_ entries: JSONValue?) -> SubmitHandler {
        let replies = Replies(entries?.arrayValue ?? [])
        let script = script
        let log = log
        return { values, skipped in
            log.record(["call": "submit", "values": .object(values), "skippedSteps": json(skipped)])
            return SubmitResult(json: try await script.reply(replies.next()))
        }
    }

    func check(_ label: String, _ actual: JSONValue?, _ expected: JSONValue?) {
        guard !jsonEqual(actual, expected) else { return }
        failures.append("\(label)\n  expected: \(render(expected))\n  actual:   \(render(actual))")
    }

    func outcome(_ label: String, _ step: JSONObject, _ result: Outcome) {
        switch result {
        case .success(let value):
            if let expected = step["throws"] {
                check("\(label) throws", nil, expected)
            } else if step.has("returns") {
                check("\(label) returns", value, step["returns"])
            }
        case .failure(let error):
            if let expected = step["throws"] {
                check("\(label) throws", errorProjection(error, expected.objectValue ?? JSONObject()), expected)
            } else {
                failures.append("\(label) threw unexpectedly: \(error)")
            }
        }
    }
}

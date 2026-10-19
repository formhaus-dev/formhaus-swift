import FormhausCore

typealias Outcome = Result<JSONValue?, any Error>

@MainActor
final class ScenarioRun {
    static let hookNames = ["onBeforeStepChange", "onAfterStepChange", "onBeforeSubmit", "onAfterSubmit", "onStepValidate"]

    let file: ScenarioFile
    let scenario: JSONObject
    private(set) var engine: FormEngine!
    let script = Script()
    var log: [JSONValue] = []
    var failures: [String] = []
    var pending: [(label: String, task: Task<Void, Never>, done: Flag)] = []

    init(_ file: ScenarioFile, _ scenario: JSONObject) throws {
        self.file = file
        self.scenario = scenario
        let values = scenario["values"]?.objectValue ?? JSONObject()
        engine = FormEngine(definition: try file.runtime(scenario), values: values, options: options())
    }

    private func hook(_ name: String) -> Replies? {
        scenario["hooks"]?[name]?.arrayValue.map(Replies.init)
    }

    private func record(_ entry: JSONObject) {
        log.append(.object(entry))
    }

    private func options() -> FormEngineOptions {
        var options = FormEngineOptions()
        let script = script
        for name in scenario["hooks"]?.objectValue?.keys ?? [] where !Self.hookNames.contains(name) {
            failures.append("unknown hook \(name)")
        }
        options.onFormEvent = { [weak self] event in self?.record(["event": json(event)]) }
        options.onWarning = { [weak self] issue in
            self?.record(["warning": ["code": .string(issue.code.rawValue), "path": .string(issue.path)]])
        }
        if let replies = hook("onBeforeStepChange") {
            options.onBeforeStepChange = { [weak self] context in
                self?.record(["call": "onBeforeStepChange", "context": json(context)])
                return flag(try await script.reply(replies.next()))
            }
        }
        if let replies = hook("onAfterStepChange") {
            options.onAfterStepChange = { [weak self] context in
                self?.record(["call": "onAfterStepChange", "context": json(context)])
                _ = try await script.reply(replies.next())
            }
        }
        if let replies = hook("onBeforeSubmit") {
            options.onBeforeSubmit = { [weak self] values in
                self?.record(["call": "onBeforeSubmit", "values": .object(values)])
                return flag(try await script.reply(replies.next()))
            }
        }
        if let replies = hook("onAfterSubmit") {
            options.onAfterSubmit = { [weak self] values, skipped in
                self?.record(["call": "onAfterSubmit", "values": .object(values), "skippedSteps": json(skipped)])
                _ = try await script.reply(replies.next())
            }
        }
        if let replies = hook("onStepValidate") {
            options.onStepValidate = { [weak self] stepId, values in
                self?.record(["call": "onStepValidate", "stepId": .string(stepId), "values": .object(values)])
                return fieldErrors(try await script.reply(replies.next()))
            }
        }
        for (name, spec) in scenario["validators"]?.objectValue ?? JSONObject() {
            let reject = spec["reject"]?.arrayValue ?? []
            let error = spec["error"]?.stringValue ?? ""
            options.validators[name] = { value, _ in reject.contains { jsonEqual(value, $0) } ? error : nil }
        }
        if let messages = scenario["messages"] { options.messages = .catalog(messages) }
        return options
    }

    func handler(_ entries: JSONValue?) -> SubmitHandler {
        let replies = Replies(entries?.arrayValue ?? [])
        let script = script
        return { [weak self] values, skipped in
            self?.record(["call": "submit", "values": .object(values), "skippedSteps": json(skipped)])
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

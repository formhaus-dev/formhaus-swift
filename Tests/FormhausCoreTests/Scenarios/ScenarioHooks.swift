import FormhausCore
import FormhausResearch

@MainActor
final class EventLog {
    var entries: [JSONValue] = []

    func record(_ entry: JSONObject) {
        entries.append(.object(entry))
    }

    func drain() -> [JSONValue] {
        defer { entries = [] }
        return entries
    }
}

@MainActor
struct ScenarioHooks {
    static let names = ["onBeforeStepChange", "onAfterStepChange", "onBeforeSubmit", "onAfterSubmit", "onStepValidate"]

    let scenario: JSONObject
    let script: Script
    let log: EventLog

    var unknownNames: [String] {
        (scenario["hooks"]?.objectValue?.keys ?? []).filter { !Self.names.contains($0) }
    }

    func options() -> FormEngineOptions {
        var options = FormEngineOptions()
        let log = log
        options.onFormEvent = { event in log.record(["event": json(event)]) }
        options.onWarning = { issue in
            log.record(["warning": ["code": .string(issue.code.rawValue), "path": .string(issue.path)]])
        }
        addStepHooks(&options)
        addSubmitHooks(&options)
        for (name, spec) in scenario["validators"]?.objectValue ?? JSONObject() {
            let reject = spec["reject"]?.arrayValue ?? []
            let error = spec["error"]?.stringValue ?? ""
            options.validators[name] = { value, _ in reject.contains { jsonEqual(value, $0) } ? error : nil }
        }
        if let messages = scenario["messages"] { options.messages = .catalog(messages) }
        options.seed = scenario["seed"]?.stringValue
        options.research = Research()
        return options
    }

    private func replies(_ name: String) -> Replies? {
        scenario["hooks"]?[name]?.arrayValue.map(Replies.init)
    }

    private func addStepHooks(_ options: inout FormEngineOptions) {
        let (log, script) = (log, script)
        if let replies = replies("onBeforeStepChange") {
            options.onBeforeStepChange = { context in
                log.record(["call": "onBeforeStepChange", "context": json(context)])
                return flag(try await script.reply(replies.next()))
            }
        }
        if let replies = replies("onAfterStepChange") {
            options.onAfterStepChange = { context in
                log.record(["call": "onAfterStepChange", "context": json(context)])
                _ = try await script.reply(replies.next())
            }
        }
        if let replies = replies("onStepValidate") {
            options.onStepValidate = { stepId, values in
                log.record(["call": "onStepValidate", "stepId": .string(stepId), "values": .object(values)])
                return fieldErrors(try await script.reply(replies.next()))
            }
        }
    }

    private func addSubmitHooks(_ options: inout FormEngineOptions) {
        let (log, script) = (log, script)
        if let replies = replies("onBeforeSubmit") {
            options.onBeforeSubmit = { values in
                log.record(["call": "onBeforeSubmit", "values": .object(values)])
                return flag(try await script.reply(replies.next()))
            }
        }
        if let replies = replies("onAfterSubmit") {
            options.onAfterSubmit = { values, skipped in
                log.record(["call": "onAfterSubmit", "values": .object(values), "skippedSteps": json(skipped)])
                _ = try await script.reply(replies.next())
            }
        }
    }
}

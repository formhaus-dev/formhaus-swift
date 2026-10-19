import FormhausCore
import Testing

@Suite("Scenario runner")
@MainActor
struct RunnerTests {
    static let file = ScenarioFile(
        name: "runner",
        definition: [
            "id": "f", "title": "F", "submit": ["label": "S"],
            "steps": [
                ["id": "one", "title": "One", "fields": [["key": "a", "type": "text", "label": "A"]]],
                ["id": "two", "title": "Two", "fields": [["key": "b", "type": "text", "label": "B"]]],
            ],
        ],
        overlay: nil, scenarios: []
    )

    func failures(_ scenario: JSONValue) async throws -> [String] {
        try await ScenarioRun(Self.file, scenario.objectValue ?? JSONObject()).run()
    }

    @Test("passes a matching scenario")
    func matching() async throws {
        let result = try await failures(["name": "ok", "steps": [["do": "next", "returns": true], ["expect": ["step": "two"]]]])
        #expect(result == [])
    }

    @Test("fails on a wrong expectation")
    func wrongExpectation() async throws {
        let result = try await failures(["name": "x", "steps": [["expect": ["step": "two"]]]])
        #expect(result.count == 1)
    }

    @Test("fails on unknown action, hook and expectation names")
    func unknownNames() async throws {
        let result = try await failures([
            "name": "x", "hooks": ["onSomething": []], "steps": [["do": "jump"], ["expect": ["color": "red"]]],
        ])
        #expect(result.contains("unknown hook onSomething"))
        #expect(result.contains { $0.contains("unknown action jump") })
        #expect(result.contains("unknown expectation color"))
    }

    @Test("fails on unsettled actions and unresolved deferred replies")
    func unsettled() async throws {
        let result = try await failures([
            "name": "x", "hooks": ["onBeforeStepChange": [["defer": "gate"]]], "steps": [["do": "next", "await": false]],
        ])
        #expect(result == ["unsettled action(s): step 0 next", "unresolved deferred reply(s): gate"])
    }

    @Test("fails when settle waits on a deferred reply")
    func settleBlocked() async throws {
        let result = try await failures([
            "name": "x", "hooks": ["onBeforeStepChange": [["defer": "gate"]]],
            "steps": [["do": "next", "await": false], ["do": "settle"]],
        ])
        #expect(result == ["step 0 next never settled"])
    }

    @Test("rejects resolving an unknown deferred reply")
    func unknownDeferred() async throws {
        await #expect(throws: ScriptError.self) {
            _ = try await failures(["name": "x", "steps": [["do": "resolve", "deferred": "nope"]]])
        }
    }

    @Test("runs a deferred reply to completion after resolve")
    func deferredFlow() async throws {
        let result = try await failures([
            "name": "x", "hooks": ["onBeforeStepChange": [["defer": "gate", "return": false]]],
            "steps": [
                ["do": "next", "await": false, "returns": false], ["expect": ["stepValidating": true]],
                ["do": "resolve", "deferred": "gate"], ["expect": ["stepValidating": false, "step": "one"]], ["do": "settle"],
            ],
        ])
        #expect(result == [])
    }

    @Test("treats a null skip handler as no handler")
    func nullHandler() async throws {
        let file = ScenarioFile(
            name: "runner",
            definition: [
                "id": "f", "title": "F", "submit": ["label": "S"],
                "steps": [["id": "one", "title": "One", "skip": true, "fields": [["key": "a", "type": "text", "label": "A"]]]],
            ],
            overlay: nil, scenarios: []
        )
        let result = try await ScenarioRun(file, ["name": "x", "steps": [["do": "skip", "handler": nil, "returns": false]]]).run()
        #expect(result == [])
    }

    @Test("coerces non-string onStepValidate errors like JavaScript String")
    func nonStringErrors() async throws {
        let result = try await failures([
            "name": "x", "hooks": ["onStepValidate": [["return": ["a": 5, "z": [1, 2]]]]],
            "steps": [["do": "next", "returns": false], ["expect": ["errors": ["a": "5"], "topLevelErrors": ["1,2"]]]],
        ])
        #expect(result == [])
    }
}

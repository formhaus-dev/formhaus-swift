import FormhausCore
import Testing

@Suite("onValidate on submit")
@MainActor
struct ValidateSubmitTests {
    @Test("gets every visible field path and runs before onBeforeSubmit")
    func scope() async throws {
        let calls = HookCalls()
        let engine = try await League.onNotes(
            FormEngineOptions(
                onBeforeSubmit: { _ in
                    calls.names.append("onBeforeSubmit")
                    return nil
                },
                onValidate: { values, context in
                    calls.names.append("onValidate")
                    calls.record(values, context)
                    return nil
                }))
        calls.names = []
        #expect(
            try await engine.submit(calls.send))
        #expect(calls.names == ["onValidate", "onBeforeSubmit", "submit"])
        #expect(calls.values.last?["notes"] == "Hi")
        #expect(calls.contexts.last?.stepId == "notes")
        #expect(calls.contexts.last?.fields == ["email", "plan", "players", "players.0.name", "players.0.role", "players.1.name", "notes"])
        #expect(calls.contexts.last?.submit == true)
    }

    @Test("leaves skipped steps out")
    func skipped() async throws {
        let calls = HookCalls()
        let engine = try League.engine(
            FormEngineOptions(onValidate: {
                calls.record($0, $1)
                return nil
            }))
        try await engine.next()
        try await engine.skip()
        try await engine.submit { _, _ in nil }
        #expect(calls.contexts.last?.fields == ["email", "plan", "notes"])
    }

    @Test("blocks the submit and opens the step of the first error")
    func blocks() async throws {
        let calls = HookCalls()
        var events: [FormEvent] = []
        let engine = try await League.onNotes(
            FormEngineOptions(
                onBeforeSubmit: { _ in
                    calls.names.append("onBeforeSubmit")
                    return nil
                },
                onValidate: { _, context in context.submit ? ["players.0.name": "Duplicate", "": "Check the roster"] : nil },
                onFormEvent: { events.append($0) }))
        #expect(
            try await engine.submit(calls.send) == false)
        #expect(calls.names.isEmpty)
        #expect(engine.currentStep?.id == "roster")
        #expect(engine.errors == ["players.0.name": "Duplicate"])
        #expect(engine.topLevelErrors == ["Check the roster"])
        #expect(!engine.submitting)
        #expect(events.contains(.formSubmitFailed(reason: .validation)))
    }

    @Test("runs on a single-step form without a step id")
    func singleStep() async throws {
        let calls = HookCalls()
        let engine = try FormEngine(
            definition: [
                "id": "single", "title": "Single", "submit": ["label": "Send"],
                "fields": [["key": "name", "type": "text", "label": "Name"]],
            ], values: ["name": "Ada"],
            options: FormEngineOptions(onValidate: { values, context in
                calls.record(values, context)
                return ["name": "Taken"]
            }))
        #expect(try await engine.submit { _, _ in nil } == false)
        #expect(calls.contexts.last?.stepId == nil)
        #expect(calls.contexts.last?.fields == ["name"])
        #expect(calls.contexts.last?.submit == true)
        #expect(engine.errors == ["name": "Taken"])
    }

    @Test("ignores a result when a checked value changes while it runs", .timeLimit(.minutes(5)))
    func staleValue() async throws {
        let check = Pending()
        let calls = HookCalls()
        let (engine, submitting) = try await League.pendingSubmit(check, calls)
        #expect(engine.submitting)
        engine.setValue("notes", "Changed")
        check.resolve(["notes": "Too short"])
        #expect(try await submitting.value == false)
        #expect(calls.names.isEmpty)
        #expect(engine.errors.isEmpty)
    }

    @Test("keeps server errors from an earlier submit next to its errors")
    func serverErrors() async throws {
        var round = 0
        let engine = try await League.onNotes(
            FormEngineOptions(onValidate: { _, context in
                guard context.submit else { return nil }
                round += 1
                return round == 2 ? ["email": "Taken"] : nil
            }))
        try await engine.submit { _, _ in .rejected(errors: ["notes": "Rejected"]) }
        #expect(engine.errors == ["notes": "Rejected"])
        #expect(try await engine.submit { _, _ in nil } == false)
        #expect(engine.errors == ["notes": "Rejected", "email": "Taken"])
        #expect(engine.currentStep?.id == "account")
    }
}

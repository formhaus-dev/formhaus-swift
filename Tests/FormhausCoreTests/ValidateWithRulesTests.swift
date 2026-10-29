import FormhausCore
import Testing

private let emails: JSONValue = [
    "id": "emails", "title": "Emails", "submit": ["label": "Send"],
    "fields": [
        ["key": "email", "type": "email", "label": "Email", "validation": ["required": true]],
        ["key": "confirm", "type": "email", "label": "Confirm"],
    ],
]

private let mismatch: ValidateFn = { _, _ in ["email": "Use a work email", "confirm": "Emails must match", "": "Check the form"] }

private let pass: ValidateFn = { _, _ in nil }

private let failure = FormEvent.formSubmitFailed(reason: .validation)

@MainActor
private func emailsEngine(_ options: FormEngineOptions, values: JSONObject = [:]) throws -> FormEngine {
    try FormEngine(definition: emails, values: values, options: options)
}

@Suite("validateWithRules")
@MainActor
struct ValidateWithRulesTests {
    @Test("runs onValidate on submit when the definition rules fail and merges both errors")
    func submitMerges() async throws {
        var events: [FormEvent] = []
        var contexts: [ValidateContext] = []
        var sent = 0
        let engine = try emailsEngine(
            FormEngineOptions(
                onValidate: { values, context in
                    contexts.append(context)
                    return try await mismatch(values, context)
                }, onFormEvent: { events.append($0) }, validateWithRules: true),
            values: ["confirm": "b@example.com"])
        #expect(
            try await engine.submit { _, _ in
                sent += 1
                return nil
            } == false)
        #expect(sent == 0)
        #expect(contexts.map(\.stepId) == [nil])
        #expect(contexts.map(\.fields) == [["email", "confirm"]])
        #expect(contexts.map(\.submit) == [true])
        #expect(engine.errors.keys == ["email", "confirm"])
        #expect(engine.errors["email"] != "Use a work email")
        #expect(engine.errors["confirm"] == "Emails must match")
        #expect(engine.topLevelErrors == ["Check the form"])
        #expect(events.filter { $0 == failure }.count == 1)
        #expect(!engine.submitting)
    }

    @Test("keeps the definition errors when onValidate passes on submit")
    func submitPasses() async throws {
        var events: [FormEvent] = []
        let engine = try emailsEngine(FormEngineOptions(onValidate: pass, onFormEvent: { events.append($0) }, validateWithRules: true))
        #expect(try await engine.submit { _, _ in nil } == false)
        #expect(engine.errors.keys == ["email"])
        #expect(events.filter { $0 == failure }.count == 1)
    }

    @Test("does not run onBeforeSubmit or the handler when the definition rules fail")
    func submitHooks() async throws {
        let calls = HookCalls()
        let engine = try emailsEngine(
            FormEngineOptions(
                onBeforeSubmit: { _ in
                    calls.names.append("onBeforeSubmit")
                    return true
                }, onValidate: mismatch, validateWithRules: true))
        #expect(try await engine.submit(calls.send) == false)
        #expect(calls.names.isEmpty)
    }

    @Test("submits when the rules and onValidate pass")
    func submits() async throws {
        let calls = HookCalls()
        let engine = try emailsEngine(FormEngineOptions(onValidate: pass, validateWithRules: true), values: ["email": "a@example.com"])
        #expect(try await engine.submit(calls.send))
        #expect(calls.names == ["submit"])
    }

    @Test("opens the first step with an error of either source on submit")
    func submitOpensStep() async throws {
        let engine = try await League.onNotes(
            FormEngineOptions(onValidate: { _, context in context.submit ? ["players.0.name": "Duplicate"] : nil }, validateWithRules: true)
        )
        engine.setValue("email", "")
        #expect(try await engine.submit { _, _ in nil } == false)
        #expect(engine.currentStep?.id == "account")
        #expect(Set(engine.errors.keys) == ["email", "players.0.name"])
        #expect(engine.errors["players.0.name"] == "Duplicate")
    }

    @Test("ignores a submit result when a checked value changes while it runs", .timeLimit(.minutes(5)))
    func submitStale() async throws {
        let check = Pending()
        var events: [FormEvent] = []
        let engine = try emailsEngine(
            FormEngineOptions(onValidate: { _, _ in await check.wait() }, onFormEvent: { events.append($0) }, validateWithRules: true))
        let submitting = Task { try await engine.submit { _, _ in nil } }
        await check.started()
        #expect(engine.submitting)
        engine.setValue("confirm", "c@example.com")
        check.resolve(["confirm": "Emails must match"])
        #expect(try await submitting.value == false)
        #expect(engine.errors["confirm"] == nil)
        #expect(!events.contains(failure))
    }

    @Test("runs onValidate on Continue when the step rules fail and merges both errors")
    func stepMerges() async throws {
        var contexts: [ValidateContext] = []
        let engine = try League.engine(
            FormEngineOptions(
                onValidate: { _, context in
                    contexts.append(context)
                    return ["email": "Taken", "plan": "Pick a paid plan", "": "Service down"]
                }, validateWithRules: true),
            values: ["plan": "solo"])
        #expect(try await engine.next() == false)
        #expect(contexts.map(\.stepId) == ["account"])
        #expect(contexts.map(\.fields) == [["email", "plan"]])
        #expect(contexts.map(\.submit) == [false])
        #expect(engine.errors.keys == ["email", "plan"])
        #expect(engine.errors["email"] != "Taken")
        #expect(engine.errors["plan"] == "Pick a paid plan")
        #expect(engine.topLevelErrors == ["Service down"])
        #expect(engine.currentStep?.id == "account")
        #expect(!engine.stepValidating)
    }

    @Test("skips onStepValidate and onBeforeStepChange when the step rules fail")
    func stepHooks() async throws {
        let calls = HookCalls()
        let engine = try League.engine(
            FormEngineOptions(
                onBeforeStepChange: { context in
                    calls.names.append("before \(context.fromStepId)")
                    return false
                },
                onStepValidate: { step, _ in
                    calls.names.append("step \(step)")
                    return nil
                },
                onValidate: { _, context in
                    calls.names.append(context.stepId ?? "")
                    return nil
                }, validateWithRules: true),
            values: [:])
        #expect(try await engine.next() == false)
        #expect(engine.errors["email"] != nil)
        #expect(calls.names == ["account"])
    }

    @Test("moves on when the step rules and onValidate pass")
    func stepPasses() async throws {
        let engine = try League.engine(FormEngineOptions(onValidate: pass, validateWithRules: true))
        #expect(try await engine.next())
        #expect(engine.currentStep?.id == "roster")
    }

    @Test("ignores a step result when a checked value changes while it runs", .timeLimit(.minutes(5)))
    func stepStale() async throws {
        let check = Pending()
        let engine = try League.engine(FormEngineOptions(onValidate: { _, _ in await check.wait() }, validateWithRules: true), values: [:])
        let moving = Task { try await engine.next() }
        await check.started()
        #expect(engine.stepValidating)
        engine.setValue("plan", "pro")
        check.resolve(["plan": "Pick a paid plan"])
        #expect(try await moving.value == false)
        #expect(engine.errors["plan"] == nil)
    }

    @Test("has no effect without onValidate")
    func withoutHook() async throws {
        let engine = try League.engine(FormEngineOptions(validateWithRules: true), values: [:])
        #expect(try await engine.next() == false)
        #expect(!engine.stepValidating)
        #expect(engine.errors.keys == ["email"])
    }
}

import FormhausCore
import Testing

@MainActor
private func once(_ result: FieldErrors, when: @escaping @Sendable (Bool) -> Bool = { _ in true }) -> ValidateFn {
    var used = false
    return { _, context in
        guard !used, when(context.submit) else { return nil }
        used = true
        return result
    }
}

private struct Offline: Error {}

@Suite("onValidate form errors")
@MainActor
struct ValidateFormErrorTests {
    @Test("clear on the next Continue")
    func nextContinue() async throws {
        let engine = try League.engine(FormEngineOptions(onValidate: once(["": "Service down"])))
        #expect(try await engine.next() == false)
        #expect(engine.topLevelErrors == ["Service down"])
        #expect(try await engine.next())
        #expect(engine.topLevelErrors.isEmpty)
    }

    @Test("clear on Back")
    func back() async throws {
        let engine = try League.engine(
            FormEngineOptions(onValidate: { _, context in context.stepId == "roster" ? ["": "Roster closed"] : nil }))
        try await engine.next()
        #expect(try await engine.next() == false)
        #expect(engine.topLevelErrors == ["Roster closed"])
        #expect(try await engine.back())
        #expect(engine.topLevelErrors.isEmpty)
    }

    @Test("clear on a Submit that fails the definition rules")
    func submit() async throws {
        let engine = try await League.onNotes(FormEngineOptions(onValidate: once(["": "Service down"]) { $0 }))
        #expect(try await engine.submit { _, _ in nil } == false)
        #expect(engine.topLevelErrors == ["Service down"])
        engine.setValue("email", "")
        #expect(try await engine.submit { _, _ in nil } == false)
        #expect(engine.errors["email"] != nil)
        #expect(engine.topLevelErrors.isEmpty)
    }

    @Test("form errors of the submit handler and of setErrors stay")
    func kept() async throws {
        var down = false
        let engine = try await League.onNotes(
            FormEngineOptions(onValidate: { _, context in context.submit && down ? ["": "Service down"] : nil }))
        try await engine.submit { _, _ in .rejected(formErrors: ["Server says no"]) }
        #expect(engine.topLevelErrors == ["Server says no"])
        down = true
        #expect(try await engine.submit { _, _ in nil } == false)
        #expect(engine.topLevelErrors == ["Server says no", "Service down"])
        down = false
        engine.setErrors(["": "External"])
        engine.setValue("email", "")
        #expect(try await engine.submit { _, _ in nil } == false)
        #expect(engine.topLevelErrors == ["External"])
    }

    @Test("from onStepValidate clear on Skip")
    func skip() async throws {
        let engine = try League.engine(
            FormEngineOptions(onStepValidate: { step, _ in step == "roster" ? ["": "Roster closed"] : nil }))
        try await engine.next()
        #expect(try await engine.next() == false)
        #expect(engine.topLevelErrors == ["Roster closed"])
        #expect(try await engine.skip())
        #expect(engine.topLevelErrors.isEmpty)
    }
}

@Suite("onValidate failures and pending calls")
@MainActor
struct ValidateFailureTests {
    @Test("Continue throws when it throws")
    func throwsOnContinue() async throws {
        let engine = try League.engine(FormEngineOptions(onValidate: { _, _ in throw Offline() }))
        await #expect(throws: Offline.self) { try await engine.next() }
        #expect(!engine.stepValidating)
        #expect(engine.currentStep?.id == "account")
    }

    @Test("Submit throws when it throws, without sending")
    func throwsOnSubmit() async throws {
        let calls = HookCalls()
        let engine = try await League.onNotes(
            FormEngineOptions(onValidate: { _, context in
                if context.submit { throw Offline() }
                return nil
            }))
        await #expect(throws: Offline.self) {
            try await engine.submit(calls.send)
        }
        #expect(calls.names.isEmpty)
        #expect(!engine.submitting)
    }

    @Test("ignores a result after reset", .timeLimit(.minutes(1)))
    func reset() async throws {
        let check = Pending()
        let engine = try League.engine(FormEngineOptions(onValidate: { _, _ in await check.wait() }))
        let moving = Task { try await engine.next() }
        await check.started()
        engine.reset(League.values)
        check.resolve(["email": "Taken", "": "Service down"])
        #expect(try await moving.value == false)
        #expect(engine.errors.isEmpty)
        #expect(engine.topLevelErrors.isEmpty)
        #expect(!engine.stepValidating)
    }

    @Test("ignores a submit result after replaceDefinition", .timeLimit(.minutes(1)))
    func replaced() async throws {
        let check = Pending()
        let calls = HookCalls()
        let (engine, submitting) = try await League.pendingSubmit(check, calls)
        var definition = try #require(League.definition.objectValue)
        definition["title"] = "League 2"
        try engine.replaceDefinition(.object(definition))
        check.resolve(["notes": "Too short"])
        #expect(try await submitting.value == false)
        #expect(calls.names.isEmpty)
        #expect(engine.errors.isEmpty)
        #expect(!engine.submitting)
    }
}

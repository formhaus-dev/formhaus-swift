import FormhausCore
import Testing

@Suite("onValidate on step change")
@MainActor
struct ValidateStepTests {
    @Test("gets the values and the visible field paths of the step, with group items")
    func scope() async throws {
        let calls = HookCalls()
        var values = League.values
        values["plan"] = "team"
        values["company"] = "Acme"
        let engine = try League.engine(
            FormEngineOptions(onValidate: {
                calls.record($0, $1)
                return nil
            }), values: values)
        #expect(try await engine.next())
        #expect(try await engine.next())
        #expect(calls.values.first?["company"] == "Acme")
        #expect(calls.values.first?["email"] == "ada@example.com")
        #expect(calls.contexts.map(\.stepId) == ["account", "roster"])
        #expect(calls.contexts.first?.fields == ["email", "plan", "company"])
        #expect(calls.contexts.last?.fields == ["players", "players.0.name", "players.0.role", "players.1.name"])
        #expect(calls.contexts.map(\.submit) == [false, false])
    }

    @Test("runs only after the built-in rules pass")
    func afterRules() async throws {
        let calls = HookCalls()
        let engine = try League.engine(
            FormEngineOptions(onValidate: {
                calls.record($0, $1)
                return nil
            }), values: [:])
        #expect(try await engine.next() == false)
        #expect(engine.errors["email"] != nil)
        #expect(calls.contexts.isEmpty)
    }

    @Test("runs after onStepValidate and before onBeforeStepChange")
    func order() async throws {
        let calls = HookCalls()
        let engine = try League.engine(
            FormEngineOptions(
                onBeforeStepChange: { _ in
                    calls.names.append("onBeforeStepChange")
                    return nil
                },
                onStepValidate: { _, _ in
                    calls.names.append("onStepValidate")
                    return nil
                },
                onValidate: { _, _ in
                    calls.names.append("onValidate")
                    return nil
                }))
        #expect(try await engine.next())
        #expect(calls.names == ["onStepValidate", "onValidate", "onBeforeStepChange"])
    }

    @Test("does not run when onStepValidate reports errors")
    func stepErrors() async throws {
        let calls = HookCalls()
        let engine = try League.engine(
            FormEngineOptions(
                onStepValidate: { _, _ in ["email": "Taken"] },
                onValidate: {
                    calls.record($0, $1)
                    return nil
                }))
        #expect(try await engine.next() == false)
        #expect(engine.errors == ["email": "Taken"])
        #expect(calls.contexts.isEmpty)
    }

    @Test("keeps the step and shows field errors")
    func fieldErrors() async throws {
        let engine = try League.engine(FormEngineOptions(onValidate: { _, _ in ["email": "Taken"] }))
        #expect(try await engine.next() == false)
        #expect(engine.currentStep?.id == "account")
        #expect(engine.errors == ["email": "Taken"])
        #expect(!engine.stepValidating)
    }

    @Test("shows errors on group item paths")
    func itemErrors() async throws {
        let engine = try League.engine(
            FormEngineOptions(onValidate: { _, context in context.stepId == "roster" ? ["players.1.name": "Name the player"] : nil }))
        try await engine.next()
        #expect(try await engine.next() == false)
        #expect(engine.errors == ["players.1.name": "Name the player"])
    }

    @Test("turns empty, unknown, hidden and other-step keys into top-level errors")
    func outsideKeys() async throws {
        let result: FieldErrors = ["": "Service down", "ghost": "Ghost", "company": "Hidden", "notes": "Later", "players.0.name": "Item"]
        let engine = try League.engine(FormEngineOptions(onValidate: { _, _ in result }))
        #expect(try await engine.next() == false)
        #expect(engine.errors.isEmpty)
        #expect(engine.topLevelErrors == ["Service down", "Ghost", "Hidden", "Later", "Item"])
    }

    @Test("passes on nil and an empty result")
    func passes() async throws {
        for result in [nil, FieldErrors()] {
            let engine = try League.engine(FormEngineOptions(onValidate: { _, _ in result }))
            #expect(try await engine.next())
        }
    }

    @Test("ignores a result when a checked value changes while it runs", .timeLimit(.minutes(1)))
    func staleValue() async throws {
        let check = Pending()
        let engine = try League.engine(FormEngineOptions(onValidate: { _, _ in await check.wait() }))
        let moving = Task { try await engine.next() }
        await check.started()
        #expect(engine.stepValidating)
        engine.setValue("plan", "pro")
        check.resolve(["email": "Taken"])
        #expect(try await moving.value == false)
        #expect(engine.errors.isEmpty)
        #expect(engine.currentStep?.id == "account")
    }

    @Test("ignores a result when the step changes while it runs", .timeLimit(.minutes(1)))
    func staleStep() async throws {
        let check = Pending()
        let engine = try League.engine(
            FormEngineOptions(onValidate: { _, context in context.stepId == "roster" ? await check.wait() : nil }))
        try await engine.next()
        let moving = Task { try await engine.next() }
        await check.started()
        engine.goToStepWithField("email")
        check.resolve(["players.0.name": "Taken"])
        #expect(try await moving.value == false)
        #expect(engine.currentStep?.id == "account")
        #expect(engine.errors.isEmpty)
    }

    @Test("does not run on Back or Skip")
    func backAndSkip() async throws {
        let calls = HookCalls()
        let engine = try League.engine(
            FormEngineOptions(onValidate: {
                calls.record($0, $1)
                return nil
            }))
        try await engine.next()
        try await engine.skip()
        try await engine.back()
        #expect(calls.contexts.count == 1)
    }
}

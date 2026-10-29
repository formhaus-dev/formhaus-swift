import FormhausCore
import Testing

@MainActor
private final class FieldErrorLog {
    var entries: [String] = []

    func record(_ event: FormEvent) {
        if case .fieldError(let fieldKey, let error) = event { entries.append("\(fieldKey): \(error)") }
    }
}

@Suite("validateWithRules field_error events")
@MainActor
struct RuleErrorEventsTests {
    @Test("reports the rule errors before onValidate runs and each error once")
    func beforeHook() async throws {
        let log = FieldErrorLog()
        let engine = try League.engine(
            FormEngineOptions(
                onValidate: { _, _ in
                    log.entries.append("onValidate")
                    return ["email": "Taken", "plan": "Pick a paid plan"]
                }, onFormEvent: log.record, validateWithRules: true),
            values: [:])
        #expect(try await engine.next() == false)
        #expect(log.entries == ["email: \(engine.errors["email"] ?? "")", "onValidate", "plan: Pick a paid plan"])
    }

    @Test("reports the rule errors when onValidate throws")
    func throwing() async throws {
        struct ServiceDown: Error {}
        let log = FieldErrorLog()
        let engine = try League.engine(
            FormEngineOptions(onValidate: { _, _ in throw ServiceDown() }, onFormEvent: log.record, validateWithRules: true), values: [:])
        await #expect(throws: ServiceDown.self) { try await engine.next() }
        #expect(log.entries == ["email: \(engine.errors["email"] ?? "")"])
    }

    @Test("reports the rule errors once when the reply is stale", .timeLimit(.minutes(5)))
    func stale() async throws {
        let check = Pending()
        let log = FieldErrorLog()
        let engine = try League.engine(
            FormEngineOptions(onValidate: { _, _ in await check.wait() }, onFormEvent: log.record, validateWithRules: true), values: [:])
        let moving = Task { try await engine.next() }
        await check.started()
        #expect(log.entries == ["email: \(engine.errors["email"] ?? "")"])
        engine.setValue("plan", "pro")
        check.resolve(["plan": "Pick a paid plan"])
        #expect(try await moving.value == false)
        #expect(log.entries == ["email: \(engine.errors["email"] ?? "")"])
    }

    @Test("reports each error once when a second submit arrives while onValidate runs", .timeLimit(.minutes(5)))
    func concurrentSubmit() async throws {
        try await concurrent { engine in try await engine.submit { _, _ in nil } }
    }

    @Test("reports each error once when a second next arrives while onValidate runs", .timeLimit(.minutes(5)))
    func concurrentNext() async throws {
        try await concurrent { engine in try await engine.next() }
    }

    private func concurrent(_ action: @escaping @MainActor (FormEngine) async throws -> Bool) async throws {
        let check = Pending()
        let log = FieldErrorLog()
        let engine = try League.engine(
            FormEngineOptions(onValidate: { _, _ in await check.wait() }, onFormEvent: log.record, validateWithRules: true), values: [:])
        let first = Task { try await action(engine) }
        await check.started()
        #expect(try await action(engine) == false)
        check.resolve(["plan": "Pick a paid plan"])
        #expect(try await first.value == false)
        #expect(log.entries == ["email: \(engine.errors["email"] ?? "")", "plan: Pick a paid plan"])
    }
}

import FormhausCore
import Testing

@Suite("Actions suspend where TypeScript awaits")
@MainActor
struct AwaitOrderTests {
    static let steps: JSONValue = [
        "id": "m", "title": "M", "submit": ["label": "S"],
        "steps": [
            ["id": "one", "title": "1", "fields": [["key": "a", "type": "text", "label": "A"]]],
            ["id": "two", "title": "2", "fields": [["key": "c", "type": "text", "label": "C"]]],
        ],
    ]
    static let flat: JSONValue = [
        "id": "f", "title": "F", "submit": ["label": "S"], "fields": [["key": "a", "type": "text", "label": "A"]],
    ]

    final class Ref {
        var engine: FormEngine?
        var calls = 0
    }

    func deferOnce(_ engine: FormEngine, while busy: KeyPath<FormEngine, Bool>, _ action: @escaping @MainActor () -> Void) {
        var once = false
        _ = engine.subscribe {
            guard engine[keyPath: busy], !once else { return }
            once = true
            Task { @MainActor in action() }
        }
    }

    @Test("a write queued while onBeforeStepChange replies synchronously makes next stale")
    func beforeStepChange() async throws {
        let engine = try FormEngine(
            definition: Self.steps, values: ["a": "x"], options: FormEngineOptions(onBeforeStepChange: { _ in true }))
        deferOnce(engine, while: \.stepValidating) { engine.setValue("a", "y") }
        #expect(try await engine.next() == false)
        #expect(engine.currentStep?.id == "one")
        #expect(engine.values["a"] == "y")
        #expect(!engine.stepValidating)
    }

    @Test("a write queued while onStepValidate replies synchronously makes next stale")
    func stepValidate() async throws {
        let engine = try FormEngine(definition: Self.steps, values: ["a": "x"], options: FormEngineOptions(onStepValidate: { _, _ in nil }))
        deferOnce(engine, while: \.stepValidating) { engine.setValue("a", "y") }
        #expect(try await engine.next() == false)
        #expect(engine.currentStep?.id == "one")
        #expect(!engine.stepValidating)
    }

    @Test("a write queued while onBeforeSubmit replies synchronously stops the submission")
    func beforeSubmit() async throws {
        let engine = try FormEngine(definition: Self.flat, values: ["a": "x"], options: FormEngineOptions(onBeforeSubmit: { _ in true }))
        deferOnce(engine, while: \.submitting) { engine.setValue("a", "y") }
        var calls = 0
        #expect(
            try await engine.submit { _, _ in
                calls += 1
                return nil
            } == false)
        #expect(calls == 0)
        #expect(engine.values["a"] == "y")
        #expect(!engine.submitting)
    }

    @Test("cancelPendingActions queued at form_submitted skips onAfterSubmit")
    func cancelDuringSubmit() async throws {
        let ref = Ref()
        let options = FormEngineOptions(
            onAfterSubmit: { _, _ in ref.calls += 1 },
            onFormEvent: { event in
                if event == .formSubmitted(fieldCount: 1) { Task { @MainActor in ref.engine?.cancelPendingActions() } }
            })
        let engine = try FormEngine(definition: Self.flat, values: ["a": "x"], options: options)
        ref.engine = engine
        #expect(try await engine.submit { _, _ in .ok })
        #expect(ref.calls == 0)
        #expect(!engine.submitting)
    }

    @Test("server errors queued at form_submitted survive a successful submit")
    func serverErrorDuringSubmit() async throws {
        let ref = Ref()
        let options = FormEngineOptions(onFormEvent: { event in
            if event == .formSubmitted(fieldCount: 0) { Task { @MainActor in ref.engine?.setErrors(["a": "taken"]) } }
        })
        let engine = try FormEngine(definition: Self.flat, options: options)
        ref.engine = engine
        #expect(try await engine.submit { _, _ in .ok })
        #expect(engine.errors == ["a": "taken"])
    }
}

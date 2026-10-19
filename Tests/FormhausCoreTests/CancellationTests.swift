import FormhausCore
import Testing

@Suite("Caller cancellation")
@MainActor
struct CancellationTests {
    static let steps = AwaitOrderTests.steps
    static let flat = AwaitOrderTests.flat

    @Test("next returns false when a hook throws CancellationError")
    func nextCancelled() async throws {
        let engine = try FormEngine(definition: Self.steps, options: FormEngineOptions(onBeforeStepChange: { _ in throw CancellationError() }))
        #expect(try await engine.next() == false)
        #expect(engine.currentStep?.id == "one")
        #expect(!engine.stepValidating)
    }

    @Test("back returns false when onBeforeStepChange throws CancellationError")
    func backCancelled() async throws {
        let cancelled = try FormEngine(
            definition: Self.steps, options: FormEngineOptions(onBeforeStepChange: { context in
                if context.reason == .back { throw CancellationError() }
                return true
            }))
        #expect(try await cancelled.next())
        #expect(try await cancelled.back() == false)
        #expect(cancelled.currentStep?.id == "two")
        #expect(!cancelled.stepValidating)
    }

    @Test("a cancelled caller task gets false from next instead of an error")
    func cancelledTask() async throws {
        let engine = try FormEngine(definition: Self.steps, options: FormEngineOptions(onStepValidate: { _, _ in
            try await Task.sleep(nanoseconds: 10_000_000_000)
            return nil
        }))
        let task = Task { @MainActor in try await engine.next() }
        await Task.yield()
        task.cancel()
        #expect(try await task.value == false)
        #expect(!engine.stepValidating)
    }

    @Test("submit returns false when the handler throws CancellationError")
    func submitCancelled() async throws {
        var events: [FormEvent] = []
        let engine = try FormEngine(definition: Self.flat, options: FormEngineOptions(onFormEvent: { events.append($0) }))
        #expect(try await engine.submit { _, _ in throw CancellationError() } == false)
        #expect(!engine.submitting)
        #expect(events.last == .formSubmitFailed(reason: .error))
    }

    @Test("submit returns false when onAfterSubmit throws CancellationError")
    func afterSubmitCancelled() async throws {
        let engine = try FormEngine(definition: Self.flat, options: FormEngineOptions(onAfterSubmit: { _, _ in throw CancellationError() }))
        #expect(try await engine.submit { _, _ in .ok } == false)
        #expect(!engine.submitting)
    }
}

import FormhausCore
import Foundation
import Testing

private struct ServerError: SubmitStatusError {
    let status: Int?
}

private struct Plain: Error {}

@Suite("Submit failures and goToStep")
@MainActor
struct SubmitFailureTests {
    private func failure(_ error: any Error) async throws -> FormEvent? {
        var events: [FormEvent] = []
        let engine = try FormEngine(definition: AwaitOrderTests.flat, options: FormEngineOptions(onFormEvent: { events.append($0) }))
        engine.start()
        await #expect(throws: (any Error).self) { try await engine.submit { _, _ in throw error } }
        return events.last
    }

    private func outcome(_ result: GoToStepResult) -> String {
        "\(result.stepId ?? "nil") \(result.reached) \(result.reason?.rawValue ?? "nil")"
    }

    @Test("a thrown error reports its status: 0 for URLError, the host status, or none")
    func status() async throws {
        #expect(try await failure(URLError(.notConnectedToInternet)) == .formSubmitFailed(reason: .error(status: 0)))
        #expect(try await failure(ServerError(status: 503)) == .formSubmitFailed(reason: .error(status: 503)))
        #expect(try await failure(ServerError(status: nil)) == .formSubmitFailed(reason: .error(status: nil)))
        #expect(try await failure(Plain()) == .formSubmitFailed(reason: .error(status: nil)))
    }

    @Test("goToStep in a form without steps stays put and reports an unknown step")
    func flat() throws {
        var events: [FormEvent] = []
        let engine = try FormEngine(definition: AwaitOrderTests.flat, options: FormEngineOptions(onFormEvent: { events.append($0) }))
        engine.start()
        events = []
        #expect(outcome(engine.goToStep("one")) == "nil false unknown-step")
        #expect(events == [.stepRedirected(requestedStepId: "one", stepId: nil, reason: .unknownStep)])
    }

    @Test("goToStep while a step change is pending stays on the current step", .timeLimit(.minutes(5)))
    func pending() async throws {
        let (started, signal) = AsyncStream<Void>.makeStream()
        let engine = try FormEngine(
            definition: AwaitOrderTests.steps,
            options: FormEngineOptions(onStepValidate: { _, _ in
                signal.yield()
                try await Task.sleep(for: .seconds(3600))
                return nil
            }))
        let task = Task { @MainActor in try await engine.next() }
        for await _ in started { break }
        #expect(outcome(engine.goToStep("two")) == "one false blocked")
        #expect(outcome(engine.goToStep("one")) == "one false blocked")
        task.cancel()
        _ = try await task.value
    }
}

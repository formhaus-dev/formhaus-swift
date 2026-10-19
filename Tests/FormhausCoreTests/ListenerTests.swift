import FormhausCore
import Foundation
import Testing

@Suite("Listeners and engine errors")
@MainActor
struct ListenerTests {
    static let definition: JSONValue = [
        "id": "f", "title": "F", "submit": ["label": "S"], "fields": [["key": "b", "type": "text", "label": "B"]],
    ]

    struct Boom: LocalizedError {
        var errorDescription: String? { "boom" }
    }

    @Test("a listener removed during notify is skipped and one added is called")
    func notifyIteration() throws {
        let engine = try FormEngine(definition: Self.definition)
        var calls = ""
        var added = false
        var cancelB: (@MainActor () -> Void)?
        let cancelA = engine.subscribe {
            calls += "A"
            cancelB?()
            if !added {
                added = true
                _ = engine.subscribe { calls += "C" }
            }
        }
        cancelB = engine.subscribe { calls += "B" }
        engine.setValue("b", "x")
        #expect(calls == "AC")
        calls = ""
        engine.setValue("b", "y")
        #expect(calls == "AC")
        cancelA()
    }

    @Test("FormLifecycleError carries the cause message")
    func lifecycleMessage() async throws {
        let engine = try FormEngine(definition: Self.definition, options: FormEngineOptions(onAfterSubmit: { _, _ in throw Boom() }))
        await #expect {
            try await engine.submit { _, _ in nil }
        } throws: { error in
            (error as? FormLifecycleError)?.message == "The action completed, but afterSubmit failed: boom"
        }
    }

    @Test("group items are identifiable and hashable")
    func groupItems() throws {
        let definition: JSONValue = [
            "id": "f", "title": "F", "submit": ["label": "S"], "formatVersion": "1.1",
            "fields": [["key": "g", "type": "group", "label": "G", "fields": [["key": "n", "type": "text", "label": "N"]]]],
        ]
        let engine = try FormEngine(definition: definition, values: ["g": [["n": "a"], ["n": "b"]]])
        let items = engine.items("g")
        #expect(Set(items).count == 2)
        #expect(Set(items.map(\.id)).count == 2)
        #expect(engine.items("g") == items)
    }
}

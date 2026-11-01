import FormhausCore
import Testing

@Suite("Dirty tracker")
@MainActor
struct DirtyTrackerTests {
    static let definition: JSONValue = [
        "id": "f", "title": "F", "submit": ["label": "S"],
        "fields": [["key": "a", "type": "text", "label": "A"], ["key": "b", "type": "text", "label": "B"]],
    ]

    @Test("listeners run once per change of the dirty keys, and not after stop")
    func listeners() throws {
        let engine = try FormEngine(definition: Self.definition, values: ["a": "x"])
        let tracker = DirtyTracker(engine: engine)
        var calls = 0
        let cancel = tracker.subscribe { calls += 1 }
        engine.setValue("a", "y")
        engine.setValue("a", "z")
        #expect(calls == 1)
        engine.setValue("b", "q")
        #expect(calls == 2)
        engine.reset(["a": "x", "b": "q"])
        #expect(calls == 3)
        #expect(tracker.dirtyKeys == [])
        #expect(engine.resetCount == 1)
        cancel()
        engine.setValue("a", "w")
        #expect(calls == 3)
        #expect(tracker.isDirty)
        tracker.stop()
        engine.setValue("a", "x")
        #expect(tracker.dirtyKeys == ["a"])
    }

    @Test("keys sort by UTF-16 code units")
    func codeUnitOrder() throws {
        let definition: JSONValue = [
            "id": "f", "title": "F", "submit": ["label": "S"],
            "fields": [["key": "\u{FF5E}", "type": "text", "label": "A"], ["key": "\u{1F600}", "type": "text", "label": "B"]],
        ]
        let engine = try FormEngine(definition: definition)
        let tracker = DirtyTracker(engine: engine)
        engine.setValue("\u{FF5E}", "x")
        engine.setValue("\u{1F600}", "y")
        #expect(tracker.dirtyKeys == ["\u{1F600}", "\u{FF5E}"])
    }
}

import FormhausCore
import Testing

@Suite("Keys enumerate in JavaScript property order")
@MainActor
struct KeyOrderTests {
    static let definition: JSONValue = [
        "id": "f", "title": "F", "submit": ["label": "S"],
        "fields": [
            ["key": "b", "type": "text", "label": "B", "validation": ["required": true]],
            ["key": "1", "type": "text", "label": "One", "validation": ["required": true]],
        ],
    ]

    @Test("array-index keys come first in numeric order, then insertion order")
    func mapOrder() {
        var map = StringMap<Int>()
        for key in ["a", "10", "2", "01", "4294967295", "4294967294", "-1", "0"] { map[key] = 1 }
        #expect(map.keys == ["0", "2", "10", "4294967294", "a", "01", "4294967295", "-1"])
        map["2"] = nil
        map["3"] = 1
        #expect(map.keys == ["0", "3", "10", "4294967294", "a", "01", "4294967295", "-1"])
    }

    @Test("field_error events and errors follow property order")
    func fieldErrorOrder() async throws {
        var events: [String] = []
        let options = FormEngineOptions(onFormEvent: { event in
            if case .fieldError(let key, _) = event { events.append(key) }
        })
        let engine = try FormEngine(definition: Self.definition, options: options)
        engine.start()
        #expect(try await engine.submit { _, _ in .ok } == false)
        #expect(events == ["1", "b"])
        #expect(engine.errors.keys == ["1", "b"])
    }

    @Test("unbound server errors reach topLevelErrors in property order")
    func topLevelOrder() throws {
        let engine = try FormEngine(definition: Self.definition)
        engine.setErrors(["zeta": "Z", "5": "five"])
        #expect(engine.topLevelErrors == ["five", "Z"])
    }

    @Test("values enumerate in property order")
    func valueOrder() throws {
        let engine = try FormEngine(definition: Self.definition)
        engine.setValue("b", "x")
        engine.setValue("1", "y")
        #expect(engine.values.keys == ["1", "b"])
    }
}

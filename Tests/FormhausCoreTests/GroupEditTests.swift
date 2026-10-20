import Foundation
import Testing

@testable import FormhausCore

private func groups(_ count: Int, items: Int) -> JSONValue {
    let fields: [JSONValue] = (0..<count).map { index in
        [
            "key": .string("g\(index)"), "type": "group", "label": "G", "defaultItems": .number(Double(items)),
            "fields": [
                ["key": "a", "type": "text", "label": "A"],
                ["key": "b", "type": "text", "label": "B", "show": [["field": "a", "neq": "hide"]]],
                ["key": "c", "type": "text", "label": "C", "show": [["field": "mode", "eq": "full"]]],
            ],
        ]
    }
    let mode: JSONValue = ["key": "mode", "type": "text", "label": "M"]
    return ["id": "p", "title": "P", "submit": ["label": "S"], "fields": .array([mode] + fields)]
}

@Suite("Group edits touch only the edited item")
@MainActor
struct GroupEditTests {
    @Test("an item condition hides and restores only its own item")
    func itemCondition() throws {
        let engine = try FormEngine(definition: groups(2, items: 3), values: ["mode": "full"])
        engine.setItemValue("g0", 1, "b", "kept")
        engine.setItemValue("g0", 1, "a", "hide")
        #expect(engine.items("g0").map { $0.fields.map(\.key) } == [["a", "b", "c"], ["a", "c"], ["a", "b", "c"]])
        #expect(engine.values["g0"]?.arrayValue?[1].objectValue?["b"] == nil)
        engine.setItemValue("g0", 1, "a", "show")
        #expect(engine.values["g0"]?.arrayValue?[1].objectValue?["b"] == "kept")
        #expect(engine.items("g1").allSatisfy { $0.fields.count == 3 })
    }

    @Test("an outer condition reaches every item of every group")
    func outerCondition() throws {
        let engine = try FormEngine(definition: groups(2, items: 2), values: ["mode": "full"])
        engine.setItemValue("g1", 0, "c", "x")
        engine.setValue("mode", "short")
        #expect(engine.items("g0").allSatisfy { $0.fields.map(\.key) == ["a", "b"] })
        #expect(engine.values["g1"]?.arrayValue?[0].objectValue?["c"] == nil)
        #expect(engine.getSubmitValues()["g1"]?.arrayValue?.allSatisfy { $0.objectValue?["c"] == nil } == true)
        engine.setValue("mode", "full")
        #expect(engine.values["g1"]?.arrayValue?[0].objectValue?["c"] == "x")
    }

    @Test("hidden item errors clear on the edited item")
    func itemErrors() throws {
        let engine = try FormEngine(definition: groups(1, items: 2), values: ["mode": "full"])
        engine.setErrors(["g0.0.b": "taken", "g0.1.b": "taken"])
        engine.setItemValue("g0", 0, "a", "hide")
        #expect(engine.errors == ["g0.1.b": "taken"])
    }

    @Test("field events report only the edited item")
    func events() throws {
        let log = Log()
        let engine = try FormEngine(
            definition: groups(3, items: 4), values: ["mode": "full"],
            options: FormEngineOptions(onFormEvent: { log.events.append($0) }))
        engine.start()
        engine.setItemValue("g2", 3, "a", "hide")
        engine.setItemValue("g2", 3, "a", "x")
        engine.setValue("mode", "short")
        let hidden = (0..<3).flatMap { group in (0..<4).map { FormEvent.fieldHidden(fieldKey: "g\(group).\($0).c") } }
        #expect(Array(log.events.dropFirst()) == [.fieldHidden(fieldKey: "g2.3.b"), .fieldShown(fieldKey: "g2.3.b")] + hidden)
    }

    @Test("one edit costs the same with 1 or 64 large groups", .heavy)
    func editCost() throws {
        let small = try FormEngine(definition: groups(1, items: 1000), values: ["mode": "full"])
        let large = try FormEngine(definition: groups(64, items: 1000), values: ["mode": "full"])
        let clock = ContinuousClock()
        var fastest = (small: Duration.seconds(600), large: Duration.seconds(600))
        for round in 0..<5 {
            fastest.small = min(fastest.small, clock.measure { small.setItemValue("g0", round, "a", .string("v\(round)")) })
            fastest.large = min(fastest.large, clock.measure { large.setItemValue("g0", round, "a", .string("v\(round)")) })
        }
        #expect(fastest.large / fastest.small < 8)
    }
}

@MainActor
private final class Log {
    var events: [FormEvent] = []
}

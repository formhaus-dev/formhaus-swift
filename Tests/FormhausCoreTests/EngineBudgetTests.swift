import Testing

@testable import FormhausCore

private func patterned(_ count: Int, match: String? = nil) -> [JSONValue] {
    (0..<count).map { index in
        var rules: JSONObject = ["pattern": "^a$"]
        if let match { rules["matchField"] = .string(match) }
        return ["key": .string("f\(index)"), "type": "text", "label": "F", "validation": .object(rules)]
    }
}

private func filled(_ count: Int) -> JSONObject {
    var values = JSONObject()
    for index in 0..<count { values["f\(index)"] = "a" }
    return values
}

private func steps(_ count: Int) -> JSONValue {
    [
        "id": "p", "title": "P", "submit": ["label": "S"],
        "steps": [
            ["id": "one", "title": "1", "fields": .array(patterned(count))],
            ["id": "two", "title": "2", "fields": [["key": "z", "type": "text", "label": "Z"]]],
        ],
    ]
}

private func flat(_ fields: [JSONValue]) -> JSONValue {
    ["id": "p", "title": "P", "submit": ["label": "S"], "fields": .array(fields)]
}

@Suite("Every engine entry point tests patterns inside one budget")
@MainActor
struct EngineBudgetTests {
    @Test("canGoNext")
    func canGoNext() throws {
        let open = try FormEngine(definition: steps(5), values: filled(5))
        #expect(CallBudget.$patternTestLimit.withValue(5) { open.canGoNext })
        let capped = try FormEngine(definition: steps(5), values: filled(5))
        #expect(CallBudget.$patternTestLimit.withValue(3) { !capped.canGoNext })
    }

    @Test("validate")
    func validate() throws {
        let engine = try FormEngine(definition: flat(patterned(5)), values: filled(5))
        let errors = CallBudget.$patternTestLimit.withValue(3) { engine.validate() }
        #expect(errors.keys.sorted() == ["f3", "f4"])
    }

    @Test("setValue revalidates match errors")
    func setValue() throws {
        var values = filled(5)
        values["src"] = "b"
        let fields = patterned(5, match: "src") + [["key": "src", "type": "text", "label": "S"]]
        let engine = try FormEngine(definition: flat(fields), values: values)
        #expect(engine.validate().count == 5)
        CallBudget.$patternTestLimit.withValue(3) { engine.setValue("src", "a") }
        #expect(engine.errors.keys.sorted() == ["f3", "f4"])
    }

    @Test("setItemValue revalidates match errors")
    func setItemValue() throws {
        let inner = patterned(5, match: "src") + [["key": "src", "type": "text", "label": "S"]]
        let group: JSONValue = ["key": "g", "type": "group", "label": "G", "fields": .array(inner)]
        var item = filled(5)
        item["src"] = "b"
        let engine = try FormEngine(definition: flat([group]), values: ["g": [.object(item)]])
        #expect(engine.validate().count == 5)
        CallBudget.$patternTestLimit.withValue(3) { engine.setItemValue("g", 0, "src", "a") }
        #expect(engine.errors.keys.sorted() == ["g.0.f3", "g.0.f4"])
    }

    @Test("next")
    func next() async throws {
        let open = try FormEngine(definition: steps(3), values: filled(3))
        #expect(try await CallBudget.$patternTestLimit.withValue(6) { try await open.next() })
        let capped = try FormEngine(definition: steps(3), values: filled(3))
        #expect(try await CallBudget.$patternTestLimit.withValue(4) { try await capped.next() } == false)
    }

    @Test("submit")
    func submit() async throws {
        let options = FormEngineOptions(onBeforeSubmit: { _ in true })
        let open = try FormEngine(definition: flat(patterned(3)), values: filled(3), options: options)
        #expect(try await CallBudget.$patternTestLimit.withValue(6) { try await open.submit { _, _ in .ok } })
        let capped = try FormEngine(definition: flat(patterned(3)), values: filled(3), options: options)
        #expect(try await CallBudget.$patternTestLimit.withValue(4) { try await capped.submit { _, _ in .ok } } == false)
    }
}

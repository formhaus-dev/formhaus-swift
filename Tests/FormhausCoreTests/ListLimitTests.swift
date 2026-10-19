@_spi(Renderer) import FormhausCore
import Testing

private func options(_ prefix: String, _ count: Int) -> JSONValue {
    .array((0..<count).map { ["value": .string("\(prefix)\($0)"), "label": .string("\(prefix)\($0)")] })
}

private func picks(_ prefix: String, _ count: Int) -> JSONValue {
    .array((0..<count).map { .string("\(prefix)\($0)") })
}

private let blocked: JSONValue = [["field": "choices", "notContains": "o5"]]

private func branchForm() -> JSONValue {
    func branch(_ id: String, _ count: Int) -> JSONValue {
        [
            "id": .string(id), "routes": [["to": nil]],
            "fields": [
                ["key": "tags", "type": "multiselect", "label": "Tags", "options": options("t", count)],
                ["key": .string("note\(id)"), "type": "text", "label": "Note", "show": [["field": "tags", "contains": "t1"]]],
            ],
        ]
    }
    let choices: JSONValue = [["value": "a", "label": "A"], ["value": "b", "label": "B"]]
    return [
        "id": "f", "submit": ["label": "S"],
        "steps": [
            [
                "id": "pick", "routes": [["to": "a", "show": [["field": "path", "eq": "a"]]], ["to": "b"]],
                "fields": [["key": "path", "type": "radio", "label": "P", "options": choices]],
            ],
            branch("a", 1500), branch("b", 1200),
        ],
    ]
}

@Suite("List limits follow the field that owns the value")
@MainActor struct ListLimitTests {
    @Test("next and submit guards use the static option count of the definition")
    func actionGuards() async throws {
        let engine = try FormEngine(
            definition: [
                "id": "f", "submit": ["label": "S", "disabled": blocked],
                "steps": [
                    [
                        "id": "one", "next": ["label": "Go", "disabled": blocked],
                        "fields": [["key": "choices", "type": "multiselect", "label": "C", "options": options("o", 1001)]],
                    ],
                    ["id": "two", "fields": [["key": "b", "type": "text", "label": "B"]]],
                ],
            ], values: ["choices": picks("o", 1001)])
        let next = engine.currentStep?.next.action
        #expect(!engine.isActionDisabled(next))
        #expect(!engine.actionsState(nil).primaryDisabled)
        #expect(isActionDisabled(next, engine.getSubmitValues()))
        #expect(try await engine.next())
        #expect(!engine.isActionDisabled(engine.definition.submit))
        #expect(!engine.actionsState(nil).primaryDisabled)
    }

    @Test("a shared key takes the list limit of the branch on the path", arguments: [("a", true), ("b", false)])
    func sharedKeyBranches(path: String, shown: Bool) async throws {
        let values: JSONObject = ["path": .string(path), "tags": picks("t", 1300)]
        let engine = try FormEngine(definition: branchForm(), values: values)
        #expect(try await engine.next())
        #expect(engine.visibleFields.map(\.key) == ["tags"] + (shown ? ["note\(path)"] : []))
    }
}

@_spi(Renderer) import FormhausCore
import Testing

@Suite("Definition replacement and option texts")
struct CoreAdditionsTests {
    @Test("replaceDefinition takes JSON and rejects an invalid definition")
    @MainActor func replaceWithJSON() throws {
        let engine = try FormEngine(
            definition: ["id": "f", "submit": ["label": "S"], "fields": [["key": "a", "type": "text", "label": "A"]]], values: ["a": "x"])
        try engine.replaceDefinition([
            "id": "f", "submit": ["label": "S"],
            "fields": [["key": "a", "type": "text", "label": "A"], ["key": "b", "type": "text", "label": "B", "defaultValue": "y"]],
        ])
        #expect(engine.values == ["a": "x", "b": "y"])
        #expect(throws: FormDefinitionError.self) { try engine.replaceDefinition(["id": "f"]) }
        #expect(engine.values == ["a": "x", "b": "y"])
    }

    @Test("option texts tell repeated labels apart")
    func repeatedLabels() throws {
        let definition = try FormDefinition(json: [
            "id": "f", "submit": ["label": "S"],
            "fields": [
                [
                    "key": "city", "type": "select", "label": "City",
                    "options": [
                        ["value": "a", "label": "Paris"], ["value": "b", "label": "Paris"], ["value": "c", "label": "Rome"],
                        ["value": "x", "label": "Lyon (y)"], ["value": "y", "label": "Lyon"], ["value": "z", "label": "Lyon"],
                    ],
                ]
            ],
        ])
        let options = try #require(definition.fields?.first?.field?.options)
        #expect(optionTexts(options) == ["Paris (a)", "Paris (b)", "Rome", "Lyon (y) (1)", "Lyon (y) (2)", "Lyon (z)"])
    }

    @Test("error groups follow the steps and join labels by punctuation")
    @MainActor func errorGroups() throws {
        let engine = try FormEngine(definition: [
            "id": "f", "submit": ["label": "S"],
            "steps": [
                ["id": "one", "title": "Contact", "fields": [["key": "a", "type": "text", "label": "Name?"]]],
                [
                    "id": "two",
                    "fields": [["key": "b", "type": "text", "label": "City"], ["key": "c", "type": "text", "label": "Zip\u{FF1A}"]],
                ],
            ],
        ])
        engine.setErrors(["c": "Bad", "a": "Taken", "b": "Missing"])
        let groups = engine.errorGroups(nil)
        #expect(groups.map(\.id) == ["one", "two"])
        #expect(groups.map(\.title) == ["Contact", "Step 2"])
        #expect(groups.flatMap(\.entries).map(\.text) == ["Name? Taken", "City: Missing", "Zip\u{FF1A} Bad"])
        #expect(groups.flatMap(\.entries).map(\.key) == ["a", "b", "c"])
    }
}

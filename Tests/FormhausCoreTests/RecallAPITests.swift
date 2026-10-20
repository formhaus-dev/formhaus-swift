@_spi(Renderer) import FormhausCore
import Testing

@Suite("Answer recall and choice hints")
struct RecallAPITests {
    @Test("recallStatic shows labels and item keys of a group")
    func staticLabels() throws {
        let definition = try FormDefinition(json: [
            "formatVersion": "1.5", "id": "f", "submit": ["label": "S"],
            "fields": [
                ["key": "name", "type": "text", "label": "Name"], ["key": "plain", "type": "text", "label": ""],
                ["key": "people", "type": "group", "label": "People", "fields": [["key": "guest", "type": "text", "label": "Guest"]]],
            ],
        ])
        #expect(recallStatic(definition, "{{name}}, {{ plain }}, {{nope}}, \\{{name}}") == "Name, plain, , {{name}}")
        #expect(recallStatic(definition, "{{guest}} of {{people}}", group: "people") == "Guest of People")
    }

    @Test("recall stays off below format 1.5 and texts are cut at 10,000 code units")
    func versionAndLimit() throws {
        let old = try FormDefinition(json: ["id": "f", "submit": ["label": "S"], "fields": [["key": "a", "type": "text", "label": "A"]]])
        #expect(recallText(old, "{{a}}", ["a": "x"]) == "{{a}}")
        let definition = try FormDefinition(json: [
            "formatVersion": "1.5", "id": "f", "submit": ["label": "S"], "fields": [["key": "a", "type": "text", "label": "A"]],
        ])
        let value = String(repeating: "a", count: 9999) + "😀"
        let text = recallText(definition, "{{a}}", ["a": .string(value)], options: RecallOptions(format: { answer, _, _ in answer.stored }))
        #expect(text.utf16.count == 9999)
    }

    @Test("renderers get autofill sections and exclusive dividers")
    @MainActor func rendererHints() throws {
        let engine = try FormEngine(definition: [
            "formatVersion": "1.5", "id": "f", "submit": ["label": "S"],
            "fields": [
                [
                    "key": "guest_list", "type": "group", "label": "Guests",
                    "fields": [
                        ["key": "name", "type": "text", "label": "Name", "autocomplete": " name "],
                        ["key": "home", "type": "text", "label": "Home", "autocomplete": "Section-home street-address"],
                        ["key": "off", "type": "text", "label": "Off", "autocomplete": "off"],
                    ],
                ],
                [
                    "key": "pick", "type": "multiselect", "label": "Pick",
                    "options": [["value": "a", "label": "A"], ["value": "n", "label": "None", "exclusive": true]],
                ],
            ],
        ])
        let fields = try #require(engine.definition.fields?.first?.field?.items)
        #expect(engine.autocomplete(fields[0], at: "guest_list.1.name") == "section-guest_5f_list-1 name")
        #expect(engine.autocomplete(fields[1], at: "guest_list.1.home") == "section-guest_5f_list-1-home street-address")
        #expect(engine.autocomplete(fields[2], at: "guest_list.1.off") == "off")
        #expect(engine.autocomplete(fields[0]) == " name ")
        let pick = try #require(engine.definition.fields?.last?.field)
        let options = pick.options ?? []
        #expect(!dividerBefore(pick, options, 0) && dividerBefore(pick, options, 1))
    }
}

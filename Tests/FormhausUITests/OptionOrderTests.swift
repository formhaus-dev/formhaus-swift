import FormhausCore
import FormhausResearch
import FormhausUI
import Testing

private let survey: JSONValue = [
    "formatVersion": "1.6", "id": "s", "title": "S", "submit": ["label": "Send"],
    "fields": [
        [
            "key": "tools", "type": "multiselect", "label": "Tools", "randomize": true,
            "options": [
                ["value": "figma", "label": "Figma"], ["value": "sketch", "label": "Sketch"], ["value": "framer", "label": "Framer"],
                ["value": "penpot", "label": "Penpot"], ["value": "other", "label": "Other", "pinned": true],
                ["value": "none", "label": "None of these", "exclusive": true],
            ],
        ],
        [
            "key": "team", "type": "group", "label": "Team", "defaultItems": 1,
            "fields": [
                [
                    "key": "role", "type": "radio", "label": "Role", "randomize": true,
                    "options": [
                        ["value": "design", "label": "Design"], ["value": "engineering", "label": "Engineering"],
                        ["value": "product", "label": "Product"], ["value": "research", "label": "Research"],
                    ],
                ]
            ],
        ],
    ],
]

@Suite("Randomized options")
@MainActor
struct OptionOrderTests {
    private func shown(_ form: FormModel, _ field: FormField, key: String? = nil) -> [String] {
        FieldContext(field: field, key: key, model: form).options.compactMap(\.value)
    }

    @Test("fields show options in the order of the engine")
    func seededOrder() throws {
        let options = FormEngineOptions(seed: "visitor-1", research: Research())
        let form = FormModel(definition: try FormDefinition(json: survey), engineOptions: options) { _, _ in nil }
        let tools = form.structure.visibleFields[0]
        #expect(shown(form, tools) == ["penpot", "framer", "sketch", "figma", "other", "none"])
        let role = try #require(form.structure.visibleFields[1].items.first)
        #expect(shown(form, role, key: "team.0.role") == ["product", "research", "engineering", "design"])
    }

    @Test("without research the options keep their written order")
    func writtenOrder() throws {
        let options = FormEngineOptions(seed: "visitor-1")
        let form = FormModel(definition: try FormDefinition(json: survey), engineOptions: options) { _, _ in nil }
        #expect(shown(form, form.structure.visibleFields[0]) == ["figma", "sketch", "framer", "penpot", "other", "none"])
    }
}

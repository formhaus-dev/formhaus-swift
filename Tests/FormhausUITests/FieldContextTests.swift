import FormhausCore
import Testing

@testable import FormhausUI

private let choices: JSONValue = [["value": "a", "label": "A"], ["value": "b", "label": "B"]]

private let fields: JSONValue = [
    "id": "c", "title": "C", "submit": ["label": "Send"],
    "fields": [
        ["key": "name", "type": "text", "label": "Name", "validation": ["minLength": 2, "maxLength": 40]],
        ["key": "bio", "type": "textarea", "label": "Bio", "validation": ["maxLength": 500]],
        ["key": "age", "type": "number", "label": "Age", "validation": ["minLength": 1, "maxLength": 3]],
        ["key": "plan", "type": "radio", "label": "Plan", "options": choices],
        ["key": "tags", "type": "multiselect", "label": "Tags", "options": choices],
    ],
]

@Suite("Field context")
@MainActor
struct FieldContextTests {
    private func contexts(_ values: JSONObject = [:]) throws -> [String: FieldContext] {
        let model = FormModel(definition: try FormDefinition(json: fields), initialValues: values) { _, _ in .ok }
        return Dictionary(uniqueKeysWithValues: model.structure.visibleFields.map { ($0.key, FieldContext(field: $0, model: model)) })
    }

    @Test("text fields expose their length limits")
    func lengthLimits() throws {
        let contexts = try contexts()
        #expect(contexts["name"]?.minLength == 2)
        #expect(contexts["name"]?.maxLength == 40)
        #expect(contexts["bio"]?.minLength == nil)
        #expect(contexts["bio"]?.maxLength == 500)
        #expect(contexts["age"]?.minLength == nil)
        #expect(contexts["age"]?.maxLength == nil)
    }

    @Test("a radio group takes focus on its checked option")
    func checkedRadioFocus() throws {
        let contexts = try contexts(["plan": "b", "tags": ["b"]])
        #expect(focusedOption(try #require(contexts["plan"]), ["b"]) == 1)
        #expect(focusedOption(try #require(contexts["plan"]), []) == 0)
        #expect(focusedOption(try #require(contexts["tags"]), ["b"]) == 0)
    }
}

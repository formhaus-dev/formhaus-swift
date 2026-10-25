@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

private let required: JSONValue = [
    "id": "r", "title": "R", "submit": ["label": "Send"],
    "fields": [
        [
            "key": "contact", "type": "radio", "label": "Contact", "validation": ["required": true],
            "options": [["value": "email", "label": "Email"], ["value": "phone", "label": "Phone"]],
        ],
        ["key": "email", "type": "email", "label": "Email", "validation": ["required": true]],
        ["key": "age", "type": "number", "label": "Age", "validation": ["required": true]],
    ],
]

@Suite("Errors of the focused field")
@MainActor
struct FocusErrorTests {
    @Test("writing back the shown text keeps the error of an empty field", arguments: ["email", "age"])
    func sameText(key: String) async throws {
        let model = FormModel(definition: try FormDefinition(json: required)) { _, _ in nil }
        await model.submit()
        let field = try #require(model.structure.visibleFields.first { $0.key == key })
        let context = FieldContext(field: field, model: model)
        var draft = ""
        let binding = key == "age" ? context.numberBinding(Binding(get: { draft }, set: { draft = $0 })) : context.textBinding
        binding.wrappedValue = ""
        #expect(model.field(key).error != nil)
        binding.wrappedValue = "4"
        #expect(model.field(key).error == nil)
    }

    @Test("text typed while the form is locked and deleted again is not replayed", arguments: ["email", "age"])
    func revertedHeldEdit(key: String) throws {
        let model = FormModel(definition: try FormDefinition(json: required)) { _, _ in nil }
        let field = try #require(model.structure.visibleFields.first { $0.key == key })
        model.field(key).noteFocus(true)
        model.loading = true
        var draft = ""
        let context = FieldContext(field: field, model: model)
        let binding = key == "age" ? context.numberBinding(Binding(get: { draft }, set: { draft = $0 })) : context.textBinding
        binding.wrappedValue = "42"
        binding.wrappedValue = ""
        model.loading = false
        #expect(FieldContext(field: field, model: model).text.isEmpty)
    }
}

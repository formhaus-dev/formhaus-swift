import FormhausCore
import FormhausUI
import SwiftUI
import Testing

private let helpers: JSONValue = [
    "id": "h", "title": "H", "submit": ["label": "Send"],
    "fields": [
        [
            "key": "tags", "type": "multiselect", "label": "Tags",
            "options": [["value": "a", "label": "A", "image": "https://example.com/a.png"], ["value": "b", "label": "B"]],
        ],
        [
            "key": "ease", "type": "scale", "label": "Ease", "validation": ["min": 1, "max": 11],
            "options": [["value": "1", "label": "Hard"]],
        ],
    ],
]

@Suite("Public helpers for custom sets")
@MainActor
struct HelperAPITests {
    @Test("ChoiceSelection reads and toggles values")
    func selection() throws {
        let form = FormModel(definition: try FormDefinition(json: helpers)) { _, _ in nil }
        let field = form.structure.visibleFields[0]
        ChoiceSelection(context: FieldContext(field: field, model: form)).choose("b")
        let selection = ChoiceSelection(context: FieldContext(field: field, model: form))
        #expect(selection.multiple && selection.values == ["b"] && selection.isSelected("b"))
        let image = FormhausOptionImage(option: field.options?[0] ?? FieldOption(value: "a", label: "A"), contentMode: .fit)
        #expect(type(of: image.body) != Never.self)
    }

    @Test("ScalePoints lists points, anchors and clamps")
    func scale() throws {
        let form = FormModel(definition: try FormDefinition(json: helpers), initialValues: ["ease": 3]) { _, _ in nil }
        let scale = ScalePoints(FieldContext(field: form.structure.visibleFields[1], model: form))
        #expect(scale.points.count == 11 && scale.low == 1 && scale.high == 11)
        #expect(scale.anchor(for: 1) == "Hard" && scale.selected(.number(3)) == 3 && scale.clamped(500) == 11)
    }
}

import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

private let types = [
    "text", "email", "phone", "number", "password", "textarea", "autocomplete", "select", "radio", "multiselect", "date", "time",
    "datetime", "file", "scale", "rating", "checkbox", "switch",
]

@Suite("Hit targets and labels", .serialized)
@MainActor
struct HitTargetTests {
    @Test("every control is at least one hit target tall and every field has a spoken name")
    func targets() throws {
        let fields: [JSONValue] = types.map { type in
            [
                "key": .string(type), "type": .string(type), "label": .string("Label \(type)"), "validation": ["required": true],
                "options": [["value": "a", "label": "A"], ["value": "b", "label": "B"]],
            ]
        }
        let definition = try FormDefinition(json: ["id": "a", "title": "A", "submit": ["label": "Send"], "fields": .array(fields)])
        let model = FormModel(definition: definition) { _, _ in nil }
        let log = FrameLog()
        let view = FormFields(model: model)
            .environment(\.formhausMeasuring, true)
            .coordinateSpace(name: measureSpace)
            .onPreferenceChange(MeasuredFrames.self) { frames in MainActor.assumeIsolated { log.frames = frames } }
            .formhausTheme(.touch)
        _ = host(view, width: 393, height: 3200)
        let minimum = FormhausTheme.touch.controls.hitTarget - 0.5
        for field in model.structure.visibleFields {
            let context = FieldContext(field: field, model: model)
            #expect(context.accessibilityName == "Label \(field.key), \(model.text(forLabel: "required"))")
            guard let control = log.frames["\(field.key)/control"] else {
                Issue.record("no control frame for \(field.key)")
                continue
            }
            #expect(control.height >= minimum, "\(field.key) \(control)")
            #expect(control.width >= minimum, "\(field.key) \(control)")
        }
    }
}

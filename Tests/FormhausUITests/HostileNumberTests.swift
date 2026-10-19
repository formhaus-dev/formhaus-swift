import AppKit
@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI
import Testing

private let hostile: [JSONValue] = [1e300, -1e300, -3, 2.5, 0, 1e15]

private func definition(_ number: JSONValue) -> JSONValue {
    let options: JSONValue = [["value": "1", "label": "One", "image": "data:image/png;base64,AA=="], ["value": "2", "label": "Two"]]
    return [
        "id": "n", "title": "N", "submit": ["label": "Send"],
        "fields": [
            ["key": "bio", "type": "textarea", "label": "Bio", "rows": number],
            ["key": "pick", "type": "radio", "label": "Pick", "columns": number, "options": options],
            ["key": "many", "type": "multiselect", "label": "Many", "columns": number, "options": options],
            ["key": "score", "type": "scale", "label": "Score", "validation": ["min": number, "max": number]],
            ["key": "low", "type": "scale", "label": "Low", "validation": ["min": number]],
            ["key": "stars", "type": "rating", "label": "Stars", "validation": ["max": number]],
            ["key": "text", "type": "text", "label": "Text", "validation": ["minLength": number, "maxLength": number]],
            [
                "key": "team", "type": "group", "label": "Team", "defaultItems": number,
                "validation": ["minLength": number, "maxLength": number],
                "fields": [["key": "name", "type": "text", "label": "Name"]],
            ],
            [
                "key": "grid", "type": "section", "layout": "matrix", "title": "Grid",
                "fields": [["key": "row", "type": "radio", "label": "Row", "columns": number, "options": options]],
            ],
        ],
    ]
}

@Suite("Hostile numbers in definitions and values", .serialized)
@MainActor
struct HostileNumberTests {
    @Test("huge, negative and fractional numbers never trap", arguments: hostile)
    func numbers(_ number: JSONValue) throws {
        _ = NSApplication.shared
        guard let parsed = try? FormDefinition(json: definition(number)) else { return }
        let values: JSONObject = ["score": number, "stars": number, "pick": number, "text": number, "team": [["name": number]]]
        let model = FormModel(definition: parsed, initialValues: values) { _, _ in nil }
        _ = model.engine.itemLimits(model.structure.visibleFields.first { $0.isGroup } ?? model.structure.visibleFields[0])
        _ = model.engine.itemHasContent("team", Int.max)
        _ = model.field("team.\(Int.max).name").value
        model.update("team.99999999999999999999.name", number)
        let host = NSHostingView(rootView: FormhausFormContent(model: model).frame(width: 360))
        host.frame = CGRect(x: 0, y: 0, width: 360, height: 900)
        host.layoutSubtreeIfNeeded()
        model.engine.validate()
        host.layoutSubtreeIfNeeded()
        #expect(model.structure.nodes.count == 9)
    }
}

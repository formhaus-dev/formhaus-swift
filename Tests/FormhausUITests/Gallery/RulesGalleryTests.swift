@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI
import Testing

private let workspace: JSONValue = [
    "formatVersion": "1.8", "id": "workspace", "title": "Workspace", "submit": ["label": "Save"],
    "fields": [
        ["key": "account", "type": "text", "label": "Account ID", "readOnly": true, "helperText": "Set by your admin"],
        ["key": "since", "type": "date", "label": "Member since", "readOnly": true],
        ["key": "seats", "type": "number", "label": "Seats"],
        [
            "key": "plan", "type": "radio", "label": "Plan",
            "options": [
                ["value": "starter", "label": "Starter", "description": "Up to 5 seats", "disabled": [["field": "seats", "gt": 5]]],
                ["value": "pro", "label": "Pro", "description": "Any number of seats"],
                ["value": "legacy", "label": "Legacy", "disabled": true],
            ],
        ],
        [
            "key": "tasks", "type": "group", "label": "Tasks", "itemLabel": "Task {index}", "reorderable": true,
            "fields": [["key": "title", "type": "text", "label": "Title"]],
        ],
    ],
]

private let values: JSONObject = [
    "account": "acct-1042", "since": "2024-03-01", "seats": 8, "plan": "pro", "tasks": [["title": "Invoices"], ["title": "Payroll"]],
]

@Suite("Gallery: option rules, read-only fields and reorder", .serialized)
@MainActor
struct RulesGalleryTests {
    @Test("descriptions, disabled options, read-only fields and move buttons")
    func rules() throws {
        let model = FormModel(definition: try FormDefinition(json: workspace), initialValues: values) { _, _ in nil }
        try renderGallery("rules", GallerySheet(title: "rules", rows: [("filled", model)]))
        try renderSystem("rules", model, height: 1100)
    }
}

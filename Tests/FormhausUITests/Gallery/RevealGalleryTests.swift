@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI
import Testing

let contactReveal: JSONValue = [
    "id": "contact", "title": "Contact", "submit": ["label": "Send"],
    "fields": [
        [
            "key": "contact", "type": "radio", "label": "How should we contact you?", "validation": ["required": true],
            "options": [["value": "email", "label": "Email"], ["value": "phone", "label": "Phone"], ["value": "post", "label": "Post"]],
        ],
        [
            "key": "email", "type": "email", "label": "Email address", "validation": ["required": true],
            "show": [["field": "contact", "eq": "email"]],
        ],
        [
            "key": "phone", "type": "phone", "label": "Phone number", "helperText": "With the country code",
            "show": [["field": "contact", "eq": "phone"]],
        ],
        ["key": "notes", "type": "textarea", "label": "Anything else?"],
    ],
]

let servicesReveal: JSONValue = [
    "id": "services", "title": "Services", "submit": ["label": "Send"],
    "fields": [
        [
            "key": "services", "type": "multiselect", "label": "What do you need?",
            "options": [
                ["value": "design", "label": "Design"], ["value": "build", "label": "Development"], ["value": "seo", "label": "SEO"],
            ],
        ],
        ["key": "pages", "type": "number", "label": "How many pages?", "show": [["field": "services", "contains": "design"]]],
        ["key": "stack", "type": "text", "label": "Preferred stack", "show": [["field": "services", "contains": "build"]]],
    ],
]

let nestedReveal: JSONValue = [
    "id": "nested", "title": "Nested", "submit": ["label": "Send"],
    "fields": [
        [
            "key": "delivery", "type": "radio", "label": "Delivery",
            "options": [["value": "ship", "label": "Ship to me"], ["value": "pickup", "label": "Pick up in store"]],
        ],
        [
            "key": "speed", "type": "radio", "label": "Shipping speed", "show": [["field": "delivery", "eq": "ship"]],
            "options": [["value": "standard", "label": "Standard"], ["value": "express", "label": "Express"]],
        ],
        ["key": "deadline", "type": "date", "label": "Needed by", "show": [["field": "speed", "eq": "express"]]],
    ],
]

@Suite("Gallery: revealed fields", .serialized)
@MainActor
struct RevealGalleryTests {
    @Test("revealed fields under their option, open, closed, nested and invalid")
    func reveals() async throws {
        let closed = try revealModel(contactReveal)
        let open = try revealModel(contactReveal, ["contact": "phone", "phone": "+1 416 555 0100"])
        let invalid = try revealModel(contactReveal, ["contact": "email"])
        await invalid.submit()
        let unanswered = try revealModel(contactReveal)
        await unanswered.submit()
        let services = try revealModel(servicesReveal, ["services": ["design", "build"], "pages": 12])
        let nested = try revealModel(nestedReveal, ["delivery": "ship", "speed": "express"])
        let rows = [
            ("closed", closed), ("open", open), ("field error", invalid), ("choice error", unanswered), ("multiselect", services),
            ("nested", nested),
        ]
        let behavior = FormBehavior(errorSummary: false, conditionalReveal: true)
        try renderGallery("reveal", GallerySheet(title: "reveal", rows: rows).formhausBehavior(behavior))
        try renderSystem("reveal-radio", open, height: 700, behavior: behavior)
        try renderSystem("reveal-error", invalid, height: 700, behavior: behavior)
        try renderSystem("reveal-multiselect", services, height: 600, behavior: behavior)
        try renderSystem("reveal-nested", nested, height: 600, behavior: behavior)
    }
}

@MainActor
func revealModel(_ definition: JSONValue, _ values: JSONObject = [:]) throws -> FormModel {
    FormModel(definition: try FormDefinition(json: definition), initialValues: values) { _, _ in nil }
}

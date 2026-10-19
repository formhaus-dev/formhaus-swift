@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI
import Testing

private let trip: JSONValue = [
    "id": "trip", "title": "Trip", "submit": ["label": "Book trip"], "cancel": ["label": "Cancel"],
    "steps": [
        [
            "id": "who", "title": "Who is travelling?", "description": "We send the tickets to the first traveller.",
            "skip": ["label": "Skip for now"],
            "fields": [
                [
                    "key": "travellers", "type": "group", "label": "Travellers", "itemLabel": "Traveller {index}",
                    "addLabel": "Add traveller", "defaultItems": 1, "validation": ["required": true, "maxLength": 4],
                    "fields": [
                        ["key": "name", "type": "text", "label": "Full name", "validation": ["required": true]],
                        ["key": "email", "type": "email", "label": "Email"],
                    ],
                ],
                ["key": "notes", "type": "textarea", "label": "Anything we should know?"],
            ],
        ],
        [
            "id": "seat", "title": "Pick a seat",
            "fields": [
                [
                    "key": "seat", "type": "radio", "label": "Seat",
                    "options": [["value": "a", "label": "Aisle"], ["value": "w", "label": "Window"]],
                ]
            ],
        ],
        ["id": "done", "title": "Review", "fields": [["key": "agree", "type": "checkbox", "label": "The details are correct"]]],
    ],
]

private let contact: JSONValue = [
    "id": "contact", "title": "Contact", "submit": ["label": "Send message"],
    "fields": [
        [
            "key": "about", "type": "section", "title": "About you", "description": "So we know who to answer.",
            "fields": [
                ["key": "name", "type": "text", "label": "Name", "validation": ["required": true]],
                ["key": "email", "type": "email", "label": "Email", "validation": ["required": true]],
            ],
        ],
        [
            "key": "topic", "type": "select", "label": "Topic",
            "options": [["value": "sales", "label": "Sales"], ["value": "help", "label": "Help"]],
        ],
        ["key": "message", "type": "textarea", "label": "Message", "validation": ["required": true, "minLength": 10]],
    ],
]

@Suite("Gallery: whole forms", .serialized)
@MainActor
struct FormGalleryTests {
    @Test("a multi-step form with a group, progress and actions")
    func steps() async throws {
        let fresh = FormModel(definition: try FormDefinition(json: trip)) { _, _ in nil }
        let invalid = FormModel(definition: try FormDefinition(json: trip)) { _, _ in nil }
        await invalid.next()
        let filled = FormModel(
            definition: try FormDefinition(json: trip),
            initialValues: ["travellers": [["name": "Ada Lovelace", "email": "ada@example.com"], ["name": "Charles Babbage"]]]
        ) { _, _ in nil }
        await filled.next()
        await filled.back()
        let sheet = GallerySheet(title: "steps", rows: [("start", fresh), ("invalid", invalid), ("two items", filled)])
            .formhausBehavior(FormBehavior(errorSummary: true, stepErrorMarks: true))
        try renderGallery("form-steps", sheet, widths: [420, 640])
    }

    @Test("a single-step form with a section, error summary and server errors")
    func single() async throws {
        let fresh = FormModel(definition: try FormDefinition(json: contact)) { _, _ in nil }
        let invalid = FormModel(definition: try FormDefinition(json: contact), initialValues: ["message": "Hi"]) { _, _ in nil }
        await invalid.submit()
        let rejected = FormModel(
            definition: try FormDefinition(json: contact),
            initialValues: ["name": "Ada", "email": "ada@example.com", "message": "Please call me back tomorrow."]
        ) { _, _ in .rejected(errors: ["email": "This address is already registered"], formErrors: ["We could not send your message."]) }
        await rejected.submit()
        let sheet = GallerySheet(title: "single", rows: [("start", fresh), ("invalid", invalid), ("rejected", rejected)])
            .formhausBehavior(FormBehavior(errorSummary: true))
        try renderGallery("form-single", sheet, widths: [420, 640])
    }
}

@_spi(Renderer) import FormhausCore
import Testing

@testable import FormhausUI

private let rows: JSONValue = [
    "id": "rows", "title": "Rows", "submit": ["label": "Save"],
    "fields": [
        ["key": "name", "type": "text", "label": "Full name", "validation": ["required": true]],
        ["key": "email", "type": "email", "label": "Email", "placeholder": "name@example.com", "validation": ["required": true]],
        ["key": "age", "type": "number", "label": "Age", "helperText": "Used for the age check only"],
        ["key": "pw", "type": "password", "label": "Password"],
        ["key": "plan", "type": "select", "label": "Plan", "options": planOptions],
        [
            "key": "seat", "type": "radio", "label": "Seat",
            "options": [["value": "a", "label": "Aisle"], ["value": "w", "label": "Window"]],
        ],
        ["key": "tags", "type": "multiselect", "label": "Interests", "options": planOptions],
        ["key": "news", "type": "switch", "label": "Product news"],
        ["key": "agree", "type": "checkbox", "label": "I agree to the terms", "validation": ["required": true]],
        ["key": "d", "type": "date", "label": "Date of birth"],
        ["key": "t", "type": "time", "label": "Arrival"],
        ["key": "cv", "type": "file", "label": "CV", "accept": ".pdf"],
    ],
]

private let blocks: JSONValue = [
    "id": "blocks", "title": "Blocks", "submit": ["label": "Send"],
    "fields": [
        ["key": "bio", "type": "textarea", "label": "About you", "placeholder": "A few words"],
        [
            "key": "ease", "type": "scale", "label": "How easy was it?", "validation": ["required": true],
            "options": [["value": "1", "label": "Hard"], ["value": "5", "label": "Easy"]],
        ],
        ["key": "nps", "type": "scale", "label": "How likely are you to recommend us?", "validation": ["min": 0, "max": 10]],
        ["key": "stars", "type": "rating", "label": "Rate your stay", "validation": ["max": 5, "required": true]],
        [
            "key": "color", "type": "radio", "label": "Colour", "columns": 2,
            "options": [
                ["value": "a", "label": "Violet", "image": .string(swatch)], ["value": "b", "label": "Graphite", "image": .string(swatch)],
            ],
        ],
        [
            "key": "agree", "type": "section", "layout": "matrix", "title": "How much do you agree?", "description": "One answer per row.",
            "fields": [
                ["key": "goals", "type": "radio", "label": "Goals are clear", "options": planOptions, "validation": ["required": true]],
                ["key": "heard", "type": "radio", "label": "I am heard", "options": planOptions],
            ],
        ],
    ],
]

private let filledRows: JSONObject = [
    "name": "Grace Hopper", "email": "grace@navy.mil", "age": 42, "pw": "hunter22", "plan": "pro", "seat": "w",
    "tags": ["free", "team"], "news": true, "agree": true, "d": "1990-05-17", "t": "14:30", "cv": "file:///tmp/grace-cv.pdf",
]

@Suite("Gallery: system set", .serialized)
@MainActor
struct SystemGalleryTests {
    @Test("row fields, empty, filled and invalid")
    func rowFields() async throws {
        try renderSystem("rows-empty", try model(rows), height: 1100)
        try renderSystem("rows-filled", try model(rows, values: filledRows), height: 1100)
        let invalid = try model(rows, values: ["email": "nope"])
        await invalid.submit()
        try renderSystem("rows-error", invalid, height: 1300, behavior: FormBehavior(errorSummary: true))
    }

    @Test("block fields, empty, filled and invalid")
    func blockFields() async throws {
        _ = await OptionImages.shared.image(ImageKey(swatch))
        try renderSystem("blocks-empty", try model(blocks), height: 1400)
        let filled: JSONObject = [
            "bio": "Rear admiral and computer scientist.", "ease": 4, "nps": 9, "stars": 3, "color": "b", "goals": "pro",
        ]
        try renderSystem("blocks-filled", try model(blocks, values: filled), height: 1400)
        let invalid = try model(blocks)
        await invalid.submit()
        try renderSystem("blocks-error", invalid, height: 1500, behavior: FormBehavior(errorSummary: true))
    }
}

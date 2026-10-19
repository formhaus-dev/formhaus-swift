import FormhausCore
import FormhausUI
import Testing

private let agreement: JSONValue = [
    ["value": "1", "label": "Disagree"], ["value": "2", "label": "Neutral"], ["value": "3", "label": "Agree"],
    ["value": "4", "label": "Strongly agree"],
]

@MainActor
private func matrix(_ values: JSONObject, validate: Bool, loading: Bool = false) throws -> FormModel {
    let rows: [JSONValue] = [
        [
            "key": "goals", "type": "radio", "label": "The goals of my team are clear", "validation": ["required": true],
            "options": agreement,
        ],
        ["key": "heard", "type": "radio", "label": "My opinion is heard", "validation": ["required": true], "options": agreement],
        [
            "key": "tools", "type": "multiselect", "label": "I have the tools I need", "helperText": "Pick all that apply",
            "options": agreement,
        ],
    ]
    let definition: JSONValue = [
        "id": "pulse", "title": "Pulse", "submit": ["label": "Send"],
        "fields": [["key": "agree", "type": "section", "layout": "matrix", "title": "How much do you agree?", "fields": .array(rows)]],
    ]
    let model = FormModel(definition: try FormDefinition(json: definition), initialValues: values) { _, _ in nil }
    if validate { model.engine.validate() }
    model.loading = loading
    return model
}

@Suite("Gallery: scale, rating and matrix", .serialized)
@MainActor
struct ScaleGalleryTests {
    @Test("scale and rating in every state")
    func scales() throws {
        try renderEntries(
            "scale",
            [
                GalleryEntry(
                    name: "nps",
                    field: [
                        "key": "score", "type": "scale", "label": "How likely are you to recommend us?",
                        "validation": ["min": 0, "max": 10],
                        "options": [["value": "0", "label": "Not at all likely"], ["value": "10", "label": "Extremely likely"]],
                    ],
                    value: 9),
                GalleryEntry(
                    name: "five",
                    field: [
                        "key": "ease", "type": "scale", "label": "How easy was it?",
                        "options": [["value": "1", "label": "Hard"], ["value": "3", "label": "Okay"], ["value": "5", "label": "Easy"]],
                    ],
                    value: 4),
                GalleryEntry(
                    name: "rating", field: ["key": "stars", "type": "rating", "label": "Rate your stay", "validation": ["max": 5]], value: 4
                ),
            ],
            widths: [420, 640])
    }

    @Test("matrix sections, narrow and wide")
    func matrices() throws {
        let rows = [
            ("empty", try matrix([:], validate: false)),
            ("filled", try matrix(["goals": "3", "heard": "2", "tools": ["1", "4"]], validate: false)),
            ("error", try matrix(["goals": "3"], validate: true)),
            ("disabled", try matrix(["goals": "3"], validate: false, loading: true)),
        ]
        try renderGallery("matrix", GallerySheet(title: "matrix", rows: rows), widths: [420, 720])
    }
}

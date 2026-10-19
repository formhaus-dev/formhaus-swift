import FormhausCore
import Testing

@testable import FormhausUI

let planOptions: JSONValue = [
    ["value": "free", "label": "Free"], ["value": "pro", "label": "Pro, billed monthly"],
    ["value": "team", "label": "Team with shared workspaces and admin controls"],
]

let swatch =
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAGCAIAAABxZ0isAAAAgUlEQVR4nA3JoRHAIAwAwF6GyBAZIk"
    + "PkrhtwWYAN2IAN2ABVG3R0NBqNxpS3/7xwEuwMq8CsEA28wzD4nhdPwp1xFZwVo6F3HIY36CTamVahWSkaeadhdINP4p15FZ6Vo7"
    + "F3HsY35CTZWVaRWSWaeJdhckNP0p11FZ1Vo6l3HabfDxk9TAn8Inp8AAAAAElFTkSuQmCC"

@Suite("Gallery: choice, date and file fields", .serialized)
@MainActor
struct ChoiceGalleryTests {
    @Test("choice fields in every state")
    func choices() throws {
        try renderEntries(
            "choice",
            [
                GalleryEntry(
                    name: "select",
                    field: ["key": "plan", "type": "select", "label": "Plan", "placeholder": "Choose a plan", "options": planOptions],
                    value: "pro"),
                GalleryEntry(
                    name: "radio", field: ["key": "plan", "type": "radio", "label": "Plan", "options": planOptions], value: "pro"),
                GalleryEntry(
                    name: "radio-inline",
                    field: [
                        "key": "size", "type": "radio", "label": "Size", "layout": "inline",
                        "options": [
                            ["value": "s", "label": "Small"], ["value": "m", "label": "Medium"], ["value": "l", "label": "Large"],
                            ["value": "xl", "label": "Extra large"],
                        ],
                    ], value: "m", states: [.filled, .error]),
                GalleryEntry(
                    name: "multiselect", field: ["key": "tags", "type": "multiselect", "label": "Interests", "options": planOptions],
                    value: ["free", "team"]),
            ])
    }

    @Test("toggles, autocomplete and picture options in every state")
    func toggles() async throws {
        _ = await InlineImages.shared.image(ImageKey(swatch))
        try renderEntries(
            "choice",
            [
                GalleryEntry(
                    name: "checkbox",
                    field: [
                        "key": "agree", "type": "checkbox", "label": "I agree to the terms of service and the privacy policy",
                        "helperText": "You can withdraw at any time",
                    ],
                    value: true),
                GalleryEntry(
                    name: "switch",
                    field: ["key": "news", "type": "switch", "label": "Send me product news", "helperText": "Once a month"],
                    value: true),
                GalleryEntry(
                    name: "autocomplete",
                    field: ["key": "city", "type": "autocomplete", "label": "City", "placeholder": "Start typing", "options": planOptions],
                    value: "Berlin"),
                GalleryEntry(
                    name: "pictures",
                    field: [
                        "key": "color", "type": "radio", "label": "Colour", "columns": 2,
                        "options": [
                            ["value": "a", "label": "Violet", "image": .string(swatch)],
                            ["value": "b", "label": "Graphite", "image": .string(swatch)],
                            ["value": "c", "label": "Sand", "image": .string(swatch)],
                        ],
                    ], value: "b", states: [.filled, .error, .disabled]),
            ])
    }

    @Test("date, time and file fields in every state")
    func dates() throws {
        try renderEntries(
            "date",
            [
                GalleryEntry(name: "date", field: ["key": "d", "type": "date", "label": "Date of birth"], value: "1990-05-17"),
                GalleryEntry(name: "time", field: ["key": "t", "type": "time", "label": "Arrival time"], value: "14:30"),
                GalleryEntry(name: "datetime", field: ["key": "dt", "type": "datetime", "label": "Pick-up"], value: "2026-10-19T09:15"),
                GalleryEntry(
                    name: "file", field: ["key": "cv", "type": "file", "label": "CV", "accept": ".pdf", "placeholder": "PDF, up to 5 MB"],
                    value: "file:///tmp/ada-lovelace-cv.pdf"),
            ])
    }
}

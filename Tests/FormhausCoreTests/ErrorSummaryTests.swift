import Testing

@testable import FormhausCore

private let tripForm: JSONObject = [
    "id": "trip", "title": "", "submit": ["label": "Send"],
    "steps": [
        [
            "id": "who", "title": "Who",
            "fields": [
                ["key": "name", "type": "text", "label": "Name", "validation": ["required": true]],
                [
                    "key": "guests", "type": "group", "label": "Guests", "defaultItems": 2,
                    "fields": [["key": "guest", "type": "text", "label": "Guest"]],
                ],
            ],
        ],
        ["id": "where", "fields": [["key": "city", "type": "text", "label": "City"]]],
    ],
]

private func entries(_ summary: ErrorSummary) -> [[String]] {
    summary.groups.map { group in [group.id, group.title] + group.entries.flatMap { [$0.key, $0.id, $0.text] } }
}

@Suite("errorSummary")
@MainActor
struct ErrorSummaryTests {
    @Test("is empty for a form without errors")
    func empty() throws {
        let summary = errorSummary(try FormEngine(definition: .object(tripForm)))
        #expect(summary == ErrorSummary(groups: [], topLevelErrors: [], count: 0))
    }

    @Test("groups field errors by step with item paths, ids and counts")
    func grouped() throws {
        let engine = try FormEngine(definition: .object(tripForm))
        engine.setErrors(["name": "Taken", "guests.1.guest": "Too short", "city": "Unknown", "coupon": "Server down"])
        let summary = errorSummary(engine, options: ErrorSummaryOptions(idPrefix: "trip"))
        #expect(
            entries(summary) == [
                [
                    "who", "Who", "name", "trip-name", "Name: Taken", "guests.1.guest", "trip-guests--1--guest",
                    "Guest (Guests 2): Too short",
                ],
                ["where", "Step 2", "city", "trip-city", "City: Unknown"],
            ])
        #expect(summary.topLevelErrors == ["Server down"])
        #expect(summary.count == 3)
    }

    @Test("uses the default id prefix")
    func defaultPrefix() throws {
        let engine = try FormEngine(definition: .object(tripForm))
        engine.setErrors(["name": "Taken"])
        #expect(errorSummary(engine).groups.first?.entries.first?.id == "fh-name")
    }

    @Test("gives colliding and unsafe keys distinct ids")
    func collisions() throws {
        let engine = try FormEngine(
            definition: [
                "id": "f", "submit": ["label": "S"],
                "fields": [
                    ["key": "a b", "type": "text", "label": "A"], ["key": "a-b", "type": "text", "label": "B"],
                    ["key": "list", "type": "group", "label": "L", "fields": [["key": "x", "type": "text", "label": "X"]]],
                    ["key": "list--0", "type": "text", "label": "C"],
                ],
            ], values: ["list": [["x": ""]]])
        engine.setErrors(["a b": "1", "a-b": "2", "list--0": "3", "list.0.x": "4"])
        let ids = errorSummary(engine, options: ErrorSummaryOptions(idPrefix: "my form")).groups.flatMap(\.entries).map(\.id)
        #expect(ids == ["my-form-a-b-4m7u2a", "my-form-a-b", "my-form-list-3lo6m9--0--x", "my-form-list--0"])
    }

    @Test("reads labels from the options before the definition")
    func labels() throws {
        var definition = tripForm
        definition["labels"] = ["stepTitle": "Part {index}", "itemLabel": "Guest {index}"]
        let engine = try FormEngine(definition: .object(definition))
        engine.setErrors(["guests.0.guest": "Missing", "city": "Unknown"])
        let summary = errorSummary(engine, options: ErrorSummaryOptions(labels: .catalog(["itemLabel": "Person {index}"])))
        #expect(summary.groups.map(\.title) == ["Who", "Part 2"])
        #expect(summary.groups.flatMap(\.entries).map(\.text) == ["Guest (Person 1): Missing", "City: Unknown"])
    }
}

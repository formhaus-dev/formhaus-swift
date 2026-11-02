import Testing

@_spi(Renderer) @testable import FormhausCore

private let teamDefinition: JSONValue = [
    "formatVersion": "1.8", "id": "team", "title": "Team", "submit": ["label": "Save"],
    "fields": [
        ["key": "name", "type": "text", "label": "Name"],
        [
            "key": "plan", "type": "radio", "label": "Plan",
            "options": [["value": "pro", "label": "Pro"], ["value": "legacy", "label": "Legacy", "disabled": true]],
        ],
        [
            "key": "people", "type": "group", "label": "People", "reorderable": true,
            "fields": [
                [
                    "key": "roles", "type": "multiselect", "label": "Roles",
                    "options": [["value": "admin", "label": "Admin", "disabled": true], ["value": "member", "label": "Member"]],
                ]
            ],
        ],
    ],
]

private func people(_ roles: [[String]]) -> JSONValue {
    .array(roles.map { ["roles": .array($0.map(JSONValue.string))] })
}

@Suite("Option rules")
@MainActor
struct OptionRulesTests {
    @Test("the server holds stored disabled options as many times as they were stored")
    func serverHolds() throws {
        let definition = try FormDefinition(json: teamDefinition)
        let previous: JSONValue = ["plan": "legacy", "people": people([["admin"], ["member"]])]
        let options = SubmissionOptions(previousValues: previous)
        let kept = try validateSubmission(
            definition, ["plan": "legacy", "people": people([["member"], ["admin", "member"]])], options: options)
        #expect(kept.errors.isEmpty)
        let copied = try validateSubmission(definition, ["people": people([["admin"], ["admin"]])], options: options)
        #expect(copied.errors.keys == ["people.1.roles"])
        let fresh = try validateSubmission(definition, ["plan": "legacy"])
        #expect(fresh.errors.keys == ["plan"])
    }

    @Test("rules evaluate in the scope of the item")
    func itemRules() throws {
        let engine = try FormEngine(
            definition: [
                "formatVersion": "1.8", "id": "rules", "title": "Rules", "submit": ["label": "Save"],
                "fields": [
                    [
                        "key": "rows", "type": "group", "label": "Rows",
                        "fields": [
                            ["key": "locked", "type": "checkbox", "label": "Locked"],
                            ["key": "note", "type": "text", "label": "Note", "readOnly": [["field": "locked", "eq": true]]],
                        ],
                    ]
                ],
            ], values: ["rows": [["locked": true], ["locked": false]]])
        let note = try #require(engine.definition.allFields.first?.items.last)
        #expect(engine.fieldRules(note, options: [], at: "rows.0.note").readOnly)
        #expect(!engine.fieldRules(note, options: [], at: "rows.1.note").readOnly)
        #expect(engine.ruleDependencies(note, options: [], at: "rows.1.note").map(\.key) == ["rows.1.locked"])
    }
}

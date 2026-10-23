import Foundation
import Testing

@_spi(Renderer) @testable import FormhausCore
@testable import FormhausResearch

@MainActor
private final class Issues {
    var codes: [IssueCode] = []
    var skipped: [[String]] = []
}

let trip: JSONValue = [
    "formatVersion": "1.6", "id": "trip", "title": "Trip", "submit": ["label": "Book"],
    "steps": [
        ["id": "who", "title": "Who", "fields": [["key": "name", "type": "text", "label": "Name", "validation": ["required": true]]]],
        [
            "id": "extras", "title": "Extras", "skip": ["label": "Skip"],
            "fields": [["key": "meal", "type": "text", "label": "Meal", "defaultValue": "veg"]],
        ],
        [
            "id": "seat", "title": "Seat",
            "fields": [
                [
                    "key": "seat", "type": "radio", "label": "Seat", "randomize": true, "validation": ["required": true],
                    "options": .array((0..<8).map { ["value": .string("s\($0)"), "label": "S"] }),
                ]
            ],
        ],
    ],
]

private let example = #"{"version":1,"definitionId":"trip","values":{"name":"Ada"},"step":"seat","skipped":["extras"],"seed":"abc"}"#

private let account: JSONValue = [
    "id": "account", "title": "Account", "submit": ["label": "Save"],
    "fields": [
        ["key": "email", "type": "email", "label": "Email"],
        ["key": "secret", "type": "password", "label": "Password", "validation": ["required": true]],
        [
            "key": "people", "type": "group", "label": "People",
            "fields": [["key": "name", "type": "text", "label": "Name"], ["key": "pin", "type": "password", "label": "PIN"]],
        ],
    ],
]

private func data(_ text: String) -> Data {
    Data(text.utf8)
}

@Suite("Form snapshot")
@MainActor
struct SnapshotTests {
    private let issues = Issues()

    private var options: FormEngineOptions {
        let issues = issues
        return FormEngineOptions(onWarning: { issues.codes.append($0.code) }, research: Research())
    }

    private var mismatches: Int { issues.codes.count { $0 == .snapshotMismatch } }

    private func restored(_ text: String, definition: FormDefinition? = nil) throws -> FormEngine {
        FormEngine(
            definition: try definition ?? FormDefinition(json: trip), options: options,
            restoring: FormSnapshot.decode(data(text), options: options))
    }

    @Test("the spec example decodes and round-trips through JSONEncoder")
    func specExample() throws {
        let spec = #"""
            {"version":1,"definitionId":"contact","values":{"email":"ann@example.com"},"step":"details",
            "skipped":["intro"],"seed":"9f2c41d07a3b88e1"}
            """#
        let snapshot = try JSONDecoder().decode(FormSnapshot.self, from: data(spec))
        #expect(snapshot.version == 1)
        #expect(snapshot.definitionId == "contact")
        #expect(snapshot.values == ["email": "ann@example.com"])
        #expect(snapshot.step == "details")
        #expect(snapshot.skipped == ["intro"])
        #expect(snapshot.seed == "9f2c41d07a3b88e1")
        let encoded = try JSONEncoder().encode(snapshot)
        #expect(try JSONValue(parsing: encoded) == JSONValue(parsing: spec))
        #expect(try JSONDecoder().decode(FormSnapshot.self, from: encoded) == snapshot)
        #expect(FormSnapshot.decode(data(spec)) == snapshot)
    }

    @Test("a form without steps or id encodes explicit nulls")
    func explicitNulls() throws {
        let engine = FormEngine(
            definition: FormDefinition(unchecked: [
                "title": "T", "submit": ["label": "S"], "fields": [["key": "a", "type": "text", "label": "A"]],
            ]))
        let json = try JSONValue(parsing: try JSONEncoder().encode(engine.snapshot())).objectValue
        #expect(json?["definitionId"] == .null)
        #expect(json?["step"] == .null)
    }

    @Test("a snapshot restores values, step, skipped steps and seed without validating")
    func restore() async throws {
        let engine = try restored(example)
        #expect(engine.restored)
        #expect(engine.currentStep?.id == "seat")
        #expect(engine.seed == "abc")
        #expect(engine.values["name"] == "Ada")
        #expect(engine.errors.isEmpty)
        #expect(engine.isStepSkipped("extras"))
        #expect(mismatches == 0)
        let fresh = try FormEngine(definition: trip, options: FormEngineOptions(seed: "abc", research: Research()))
        #expect(engine.orderOptions("seat").compactMap(\.value) == fresh.orderOptions("seat").compactMap(\.value))
        let again = engine.snapshot()
        #expect([again.definitionId, again.step, again.seed] == ["trip", "seat", "abc"])
        #expect(again.skipped == ["extras"] && again.values["name"] == "Ada")
        let issues = issues
        engine.setValue("seat", "s1")
        try await engine.submit { _, skipped in
            issues.skipped.append(skipped)
            return nil
        }
        #expect(issues.skipped == [["extras"]])
    }

    @Test(
        "a snapshot that does not match starts fresh with a warning",
        arguments: [
            (#""version":1"#, #""version":2"#), (#""definitionId":"trip""#, #""definitionId":"other""#),
            (#""definitionId":"trip""#, #""definitionId":null"#), (#""definitionId":"trip","#, ""),
            (#""step":"seat""#, #""step":"gone""#), (#"["extras"]"#, #"["gone"]"#), (#"["extras"]"#, #"["who"]"#),
        ])
    func mismatch(change: (String, String)) throws {
        let engine = try restored(example.replacingOccurrences(of: change.0, with: change.1))
        #expect(!engine.restored)
        #expect(engine.currentStep?.id == "who")
        #expect(engine.values["name"] == nil)
        #expect(engine.seed != "abc")
        #expect(mismatches == 1)
    }

    @Test("a definition without an id restores only a snapshot without a definition id", arguments: [("null", true), (#""trip""#, false)])
    func anonymous(id: String, restores: Bool) throws {
        var json = try #require(trip.objectValue)
        json["id"] = nil
        let engine = try restored(example.replacingOccurrences(of: #""trip""#, with: id), definition: FormDefinition(unchecked: json))
        #expect(engine.currentStep?.id == (restores ? "seat" : "who"))
        #expect(mismatches == (restores ? 0 : 1))
    }

    @Test(
        "malformed or wrongly typed JSON decodes to nil and reports a mismatch",
        arguments: [
            "", "[]", "{", #"{"version":"1","values":{},"skipped":[],"seed":""}"#,
            example.replacingOccurrences(of: #""definitionId":"trip""#, with: #""definitionId":5"#),
            example.replacingOccurrences(of: #""step":"seat""#, with: #""step":false"#),
            example.replacingOccurrences(of: #"["extras"]"#, with: "[1]"),
            example.replacingOccurrences(of: #""seed":"abc""#, with: #""seed":7"#),
            example.replacingOccurrences(of: #"{"name":"Ada"}"#, with: "[]"),
            example.replacingOccurrences(of: #""version":1"#, with: #""version":1.5"#),
        ])
    func malformed(text: String) throws {
        #expect(FormSnapshot.decode(data(text), options: options) == nil)
        #expect((try? JSONDecoder().decode(FormSnapshot.self, from: data(text))) == nil)
        let engine = try restored(text)
        #expect(engine.currentStep?.id == "who")
        #expect(mismatches == 2)
    }

    @Test("a snapshot leaves out password values, also inside group items")
    func passwordsLeftOut() throws {
        let values: JSONObject = ["email": "a@b.co", "secret": "hunter2", "people": [["name": "Ann", "pin": "1234"]]]
        let snapshot = try FormEngine(definition: account, values: values).snapshot()
        #expect(snapshot.values == ["email": "a@b.co", "people": [["name": "Ann"]]])
        let text = try #require(String(bytes: try JSONEncoder().encode(snapshot), encoding: .utf8))
        #expect(!text.contains("hunter2") && !text.contains("1234"))
    }

    @Test("password values in a restored snapshot stay empty")
    func passwordsStayEmpty() throws {
        let text = #"""
            {"version":1,"definitionId":"account","values":{"email":"a@b.co","secret":"hunter2",
            "people":[{"name":"Ann","pin":"1234"}]},"step":null,"skipped":[],"seed":""}
            """#
        let engine = try restored(text, definition: FormDefinition(json: account))
        #expect(engine.restored)
        #expect(engine.values["secret"] == nil)
        #expect(engine.values["email"] == "a@b.co")
        #expect(engine.values["people"]?.arrayValue?.first?.objectValue?["pin"] == nil)
        #expect(engine.values["people"]?.arrayValue?.first?.objectValue?["name"] == "Ann")
        #expect(engine.validate()["secret"] != nil)
    }

    @Test("hidden values in a snapshot follow hiddenValues", arguments: [HiddenValues.clear, .keep])
    func hiddenValues(mode: HiddenValues) throws {
        let definition: JSONValue = [
            "id": "h", "title": "H", "submit": ["label": "S"],
            "fields": [
                ["key": "work", "type": "checkbox", "label": "Work"],
                ["key": "company", "type": "text", "label": "Company", "show": [["field": "work", "eq": true]]],
            ],
        ]
        let engine = try FormEngine(definition: definition, options: FormEngineOptions(hiddenValues: mode))
        engine.setValue("work", true)
        engine.setValue("company", "Acme")
        engine.setValue("work", false)
        let snapshot = engine.snapshot()
        #expect(snapshot.values["company"] == (mode == .keep ? "Acme" : nil))
        let again = try FormEngine(definition: definition, options: FormEngineOptions(hiddenValues: mode), restoring: snapshot)
        again.setValue("work", true)
        #expect(again.values["company"] == (mode == .keep ? "Acme" : nil))
    }
}

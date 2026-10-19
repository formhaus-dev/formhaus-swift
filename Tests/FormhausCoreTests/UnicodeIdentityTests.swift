import Testing

@testable import FormhausCore

@Suite("Keys and strings compare UTF-16 code units")
struct UnicodeIdentityTests {
    static let composed = "caf\u{E9}"
    static let decomposed = "cafe\u{301}"

    private func form(_ fields: [JSONValue]) -> JSONValue {
        ["id": "f", "title": "F", "submit": ["label": "S"], "fields": .array(fields)]
    }

    private func text(_ key: String, required: Bool = false) -> JSONValue {
        var field: JSONValue = ["key": .string(key), "type": "text", "label": "L"]
        if required, case .object(var object) = field {
            object["validation"] = ["required": true]
            field = .object(object)
        }
        return field
    }

    @Test("canonically equivalent strings stay distinct")
    func distinctValues() {
        #expect(Self.composed == Self.decomposed)
        #expect(JSONValue.string(Self.composed) != .string(Self.decomposed))
        let object: JSONObject = [Self.composed: 1, Self.decomposed: 2]
        #expect(object.count == 2)
        #expect(object[Self.decomposed] == 2)
        #expect(JSONValue.string("K") != .string("\u{212A}"))
    }

    @Test("NFC and NFD keys are not duplicates")
    func duplicateKeys() {
        #expect(checkDefinition(form([text(Self.composed), text(Self.decomposed)])).isEmpty)
        #expect(checkDefinition(form([text("K"), text("\u{212A}")])).isEmpty)
        let options: JSONValue = [["value": "\u{E9}", "label": "1"], ["value": "e\u{301}", "label": "2"]]
        #expect(checkDefinition(form([["key": "s", "type": "select", "label": "s", "options": options]])).isEmpty)
    }

    @Test("a submitted NFD key does not fill an NFC field")
    func submissionKeys() throws {
        let result = try validateSubmission(form([text(Self.composed, required: true)]), [Self.decomposed: "x"])
        #expect(result.values.isEmpty)
        #expect(result.errors == [Self.composed: "This field is required"])
    }

    @Test("NFC and NFD fields keep their own values")
    func separateFields() throws {
        let definition = form([text(Self.composed, required: true), text(Self.decomposed)])
        let result = try validateSubmission(definition, [Self.decomposed: "x", Self.composed: "y"])
        #expect(result.values == [Self.composed: "y", Self.decomposed: "x"])
        #expect(result.errors.isEmpty)
    }

    @Test("placeholders end at code units, not grapheme clusters")
    func placeholderBoundaries() {
        #expect(formatText("{min}\u{301}", ["min": 3]) == "3\u{301}")
        #expect(placeholders("{a}\u{301} {b}") == ["a", "b"])
    }

    @Test("group item paths split on code units")
    func itemPaths() {
        let path = splitPath(Self.decomposed, "\(Self.decomposed).0.x")
        #expect(path?.0 == 0 && path?.1 == "x")
        #expect(splitPath(Self.composed, "\(Self.decomposed).0.x") == nil)
    }
}

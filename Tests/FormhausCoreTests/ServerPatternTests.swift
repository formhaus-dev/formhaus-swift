import Foundation
import Testing

@testable import FormhausCore

private func form(_ patterns: [String]) -> JSONValue {
    let fields = patterns.enumerated().map { index, pattern -> JSONValue in
        ["key": .string("p\(index)"), "type": "text", "label": .string("P\(index)"), "validation": ["pattern": .string(pattern)]]
    }
    return ["id": "patterns", "title": "Patterns", "submit": ["label": "Send"], "fields": .array(fields)]
}

private func values(_ texts: [String]) -> JSONValue {
    .object(JSONObject(texts.enumerated().map { ("p\($0)", JSONValue.string($1)) }))
}

private func keys(_ count: Int) -> [String] {
    (0..<count).map { "p\($0)" }
}

private func errorKeys(_ definition: JSONValue, _ texts: [String]) throws -> [String] {
    let errors = try validateSubmission(definition, values(texts)).errors
    return keys(texts.count).filter { errors[$0] != nil }
}

@Suite("Patterns on the server")
struct ServerPatternTests {
    @Test("runs every pattern of a corpus of real-world patterns")
    func realWorld() throws {
        let url = (Bundle.module.resourceURL ?? Bundle.module.bundleURL).appendingPathComponent("Fixtures/real-world-patterns.json")
        let rows = try JSONValue(parsing: Data(contentsOf: url)).arrayValue ?? []
        #expect(rows.count > 250)
        let text = { (row: JSONValue, key: String) in row[key]?.stringValue ?? "" }
        let definition = form(rows.map { text($0, "pattern") })
        #expect(try validateSubmission(definition, values(rows.map { text($0, "valid") })).errors.isEmpty)
        #expect(try errorKeys(definition, rows.map { text($0, "invalid") }) == keys(rows.count))
    }

    @Test("runs a pattern that checkDefinition reports as slow")
    func slowPatterns() throws {
        let patterns = [
            "^(a+)+$", "^(\\w+\\s?)+$", "^[A-Za-z]+(?:[ '-]?[A-Za-z]+)*$", "^\\d+\\d+$", "^(?:\(String(repeating: "a", count: 1000)))$",
        ]
        let definition = form(patterns)
        #expect(
            checkDefinition(definition).map { "\($0.code.rawValue) \($0.severity.rawValue)" }
                == patterns.map { _ in "slow-pattern warning" })
        let valid = ["aaa", "Ada Lovelace", "Mary O'Neil", "12", String(repeating: "a", count: 1000)]
        #expect(try validateSubmission(definition, values(valid)).errors.isEmpty)
        #expect(try errorKeys(definition, ["aab", "Ada!", "Mary--Jane", "1", "a"]) == keys(5))
    }

    @Test("runs a slow pattern inside a group")
    func group() throws {
        let name: JSONValue = ["key": "name", "type": "text", "label": "Name", "validation": ["pattern": "^(\\w+\\s?)+$"]]
        let definition: JSONValue = [
            "id": "patterns", "title": "Patterns", "submit": ["label": "Send"], "formatVersion": "1.1",
            "fields": [["key": "people", "type": "group", "label": "People", "fields": [name]]],
        ]
        #expect(try validateSubmission(definition, ["people": [["name": "Ada Lovelace"]]]).errors.isEmpty)
        #expect(try validateSubmission(definition, ["people": [["name": "Ada!"]]]).errors == ["people.0.name": "Invalid format"])
    }

    @Test("matches the browser engine on a slow pattern")
    @MainActor func matchesEngine() throws {
        let definition = form(["^\\d+\\.?\\d*$"])
        let long = String(repeating: "1", count: 1001)
        #expect(try validateSubmission(definition, ["p0": .string(long)]).errors.isEmpty)
        #expect(try FormEngine(definition: definition, values: ["p0": .string(long)]).validate().isEmpty)
    }
}

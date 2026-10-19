import Foundation
import FormhausCore
import Testing

struct IssueEntry: Hashable, CustomStringConvertible {
    let code: String
    let path: String

    var description: String { "\(path) \(code)" }

    static func sorted(_ entries: [IssueEntry]) -> [IssueEntry] {
        entries.sorted { a, b in
            if !a.path.utf16.elementsEqual(b.path.utf16) { return a.path.utf16.lexicographicallyPrecedes(b.path.utf16) }
            return a.code.utf16.lexicographicallyPrecedes(b.code.utf16)
        }
    }

    static func list(_ value: JSONValue?) -> [IssueEntry]? {
        value?.arrayValue?.map { IssueEntry(code: $0["code"]?.stringValue ?? "", path: $0["path"]?.stringValue ?? "") }
    }
}

struct CorpusCase {
    let name: String
    let values: JSONValue
    let skippedSteps: JSONValue
    let expectedValues: JSONValue
    let expectedErrors: JSONValue
    let canSubmit: Bool

    init(_ json: JSONValue) {
        name = json["name"]?.stringValue ?? ""
        values = json["input"]?["values"] ?? .object(JSONObject())
        skippedSteps = json["input"]?["skippedSteps"] ?? .array([])
        expectedValues = json["expected"]?["values"] ?? .object(JSONObject())
        expectedErrors = json["expected"]?["errors"] ?? .object(JSONObject())
        canSubmit = json["canSubmit"]?.boolValue ?? false
    }
}

struct CorpusFixture {
    let name: String
    let issues: [IssueEntry]
    let warnings: [IssueEntry]?
    let definition: JSONValue
    let overlay: JSONValue?
    let texts: JSONObject?
    let cases: [CorpusCase]

    init(_ json: JSONValue) {
        name = json["name"]?.stringValue ?? ""
        issues = IssueEntry.list(json["issues"]) ?? []
        warnings = IssueEntry.list(json["warnings"])
        definition = json["definition"] ?? .null
        overlay = json["overlay"]
        texts = json["texts"]?.objectValue
        cases = (json["cases"]?.arrayValue ?? []).map(CorpusCase.init)
    }

    func runtime() throws -> FormDefinition {
        guard let overlay else { return try FormDefinition(json: definition) }
        return try localize(definition, overlay: overlay).definition
    }
}

enum Corpus {
    static let directory = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!.appendingPathComponent("conformance")

    static func jsonFiles(in directory: URL) -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return files.filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.sorted()
    }

    static let names = jsonFiles(in: directory)

    static func load(_ url: URL) -> JSONValue {
        do {
            return try JSONValue(parsing: Data(contentsOf: url))
        } catch {
            fatalError("cannot load \(url.lastPathComponent): \(error)")
        }
    }

    static func fixture(_ name: String) -> CorpusFixture {
        CorpusFixture(load(directory.appendingPathComponent("\(name).json")))
    }

    static let caseNames: [String] = names.flatMap { name in
        let fixture = fixture(name)
        return fixture.issues.isEmpty ? fixture.cases.map { "\(name): \($0.name)" } : []
    }

    static func testCase(_ id: String) throws -> (CorpusFixture, CorpusCase) {
        let separator = try #require(id.range(of: ": "))
        let fixture = fixture(String(id[..<separator.lowerBound]))
        let name = String(id[separator.upperBound...])
        let matches = fixture.cases.filter { sameUnits($0.name, name) }
        try #require(matches.count == 1, "\(matches.count) cases named \(id)")
        return (fixture, matches[0])
    }
}

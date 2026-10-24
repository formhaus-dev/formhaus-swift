import Testing

@testable import FormhausCore

private func form(_ fields: [JSONValue]) -> JSONValue {
    ["id": "f", "title": "F", "submit": ["label": "S"], "fields": .array(fields)]
}

private func text(_ key: String, _ pattern: String, message: String? = nil) -> JSONValue {
    var validation: JSONObject = ["pattern": .string(pattern)]
    if let message { validation["patternMessage"] = .string(message) }
    return ["key": .string(key), "type": "text", "label": "T", "validation": .object(validation)]
}

private func refused(_ definition: JSONValue) -> [String] {
    do {
        _ = try validateSubmission(definition, .object(JSONObject()))
        return []
    } catch {
        return error.issues.map(\.path)
    }
}

@Suite("Quadratic patterns on the server")
struct QuadraticPatternTests {
    @Test("the allowlist takes one overlapping repeat after a caret")
    func allowlist() {
        let quadratic = [
            "^\\d+\\.?\\d*$", "^[0-9]+\\s?[0-9]+$", "^(\\d+)\\.?(\\d*)$", "^[A-Za-z]+\\s?[A-Za-z]*$", "^\\d+(\\d*)$",
            "^\\d+\\.?\\d*\\$", "^[a-z-]+[a-z]*1", "^(?:\\w+)\\w*", "^\\d+\\.?\\d?\\d*$", "^\\d+\\d*",
        ]
        let other = [
            "\\d+\\.?\\d*$", "^\\d*\\d*\\d*$", "^\\d+\\D?\\d*$", "^\\d+\u{E9}?\\d*$", "^\\d+?\\d*$", "^\\d+\\d*?$", "^\\d{1,3}\\d*$",
            "^(\\d+)+$", "^\\d+(\\d*)", "^[z-a]+a*$", "^[\\d-z]+\\d*$", "^[^a]+a*$", "^\\d+$|^x\\d*$", "^\\d+1\\d*$",
            "^(\\d+(\\d*))$", "^\\d+[\\b]\\d*$", "^\\d+\\d*\\\\$", "^\\d+\\d*(", "^[a-z-]+[a-z]*x",
        ]
        for pattern in quadratic { #expect(isQuadratic(Array(pattern.utf16)), "\(pattern)") }
        for pattern in other { #expect(!isQuadratic(Array(pattern.utf16)), "\(pattern)") }
    }

    @Test("verdicts follow the slow-pattern check and the allowlist")
    func verdicts() {
        #expect(patternVerdict("^\\d+$") == .safe)
        #expect(patternVerdict("^\\d+\\.?\\d*$") == .quadratic)
        #expect(patternVerdict("^(a+)+$") == .refused)
        #expect(patternVerdict(String(repeating: "a", count: 1001)) == .refused)
        #expect(patternVerdict(String(repeating: "a", count: 1000)) == .safe)
    }

    @Test("canonically equivalent patterns keep their own verdicts")
    func exactVerdictKeys() {
        #expect(patternVerdict("\\d+\u{E9}?\\d*") == .refused)
        #expect(patternVerdict("\\d+e\u{301}?\\d*") == .safe)
    }

    @Test("refused patterns are reported at their path, also inside groups and steps")
    func refusedPaths() throws {
        let group: JSONValue = ["key": "people", "type": "group", "label": "P", "fields": [text("name", "^(a+)+$")]]
        #expect(refused(form([text("a", "^\\d+$"), group])) == ["/fields/1/fields/0/validation/pattern"])
        let steps: JSONValue = [
            "id": "f", "title": "F", "submit": ["label": "S"],
            "steps": [["id": "one", "fields": [text("a", "^\\d+\\.?\\d*$")]], ["id": "two", "fields": [text("b", "(x*)*")]]],
        ]
        #expect(refused(steps) == ["/steps/1/fields/0/validation/pattern"])
        do {
            _ = try validateSubmission(form([text("long", String(repeating: "a", count: 1001))]), [:])
            Issue.record("a pattern over 1000 characters runs on the server")
        } catch {
            let issue = try #require(error.issues.first)
            #expect(issue.code == .slowPattern && issue.isError)
            let problem = "the pattern of \"long\" can take very long on some values, so the server does not run it."
            let hint = "Rewrite it without nested or overlapping repeats, in 1000 characters or less."
            #expect(issue.message == "/fields/0/validation/pattern: \(problem) \(hint)")
        }
    }

    @Test("the engine accepts refused patterns")
    @MainActor func engineRuns() throws {
        let engine = try FormEngine(definition: form([text("a", "^(a+)+$")]), values: ["a": "aaa"])
        #expect(engine.validate().isEmpty)
    }

    @Test("the server checks quadratic patterns on values up to 1000 characters")
    @MainActor func valueLimit() throws {
        let definition = form([text("a", "^\\d+\\.?\\d*$", message: "Digits"), text("b", "^\\d+$")])
        let long = String(repeating: "1", count: 1001)
        let short = String(repeating: "1", count: 1000)
        #expect(try validateSubmission(definition, ["a": .string(short), "b": .string(long)]).errors.isEmpty)
        #expect(try validateSubmission(definition, ["a": .string(long), "b": .string(long)]).errors == ["a": "Digits"])
        let engine = try FormEngine(definition: definition, values: ["a": .string(long)])
        #expect(engine.validate().isEmpty)
        let field = try #require(FormDefinition(json: definition).fields?.first?.field)
        #expect(validateFieldValue(field, .string(long), [:]) == nil)
    }

    @Test("ASCII sets count and name single members")
    func asciiSets() {
        var set = AsciiSet()
        #expect(set.isEmpty && set.single == nil)
        set.insert(0x7F)
        #expect(set.single == 0x7F && set.contains(0x7F) && !set.contains(0x3F))
        set.insert(0x00)
        set.insert(0x100)
        #expect(set.count == 2 && set.single == nil && !set.contains(0x100))
        #expect(AsciiSet.all.count == 128)
        var counts = AsciiCounts()
        counts.add(AsciiSet(0x2E))
        #expect(counts.appearsOnce(0x2E))
        counts.add(counts)
        #expect(!counts.appearsOnce(0x2E) && counts.once.contains(0x2E))
    }
}

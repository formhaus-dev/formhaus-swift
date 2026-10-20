import FormhausCore
import Testing

private func patternForm(_ patterns: [String]) -> JSONValue {
    let fields = patterns.enumerated().map { index, pattern -> JSONValue in
        ["key": .string("p\(index)"), "type": "text", "label": "P", "validation": ["pattern": .string(pattern)]]
    }
    return ["id": "f", "title": "F", "submit": ["label": "S"], "fields": .array(fields)]
}

private func codes(_ patterns: [String]) -> [String] {
    checkDefinition(patternForm(patterns)).map { "\($0.severity.rawValue) \($0.code.rawValue) \($0.path)" }
}

@Suite("Slow pattern warnings")
struct SlowPatternTests {
    @Test("adjacent repeated parts that overlap are slow")
    func adjacent() throws {
        let slow = ["^\\d*\\d*\\d*\\d*\\d*x$", "a*a*b", ".*.*x", "\\d+\\w+", "[a-c]+[c-e]*", "(?:a|b)*a{2,}", "x(?:\\s*\\s+)y"]
        let fast = ["^\\d+-\\d+$", "[a-z]+@[a-z]+", "a*b*", "\\d*\\D*", "a?a?", "a+(?=a)a+", "\\(a*\\)a*", "^\\d+\\.?\\d*$"]
        let issues = checkDefinition(patternForm(slow + fast))
        #expect(issues.map(\.path) == slow.indices.map { "/fields/\($0)/validation/pattern" })
        let first = try #require(issues.first)
        #expect(first.code == .slowPattern && first.severity == .warning)
        let message =
            "/fields/0/validation/pattern: the pattern of \"p0\" repeats overlapping parts next to each other and can be very slow."
        #expect(first.message == message + " Merge the repeated parts into one.")
        #expect(checkDefinition(patternForm(["(\\w+\\s?)+"])).first?.hint == "Remove the inner or outer quantifier.")
    }

    @Test("adversarial patterns are invalid")
    func adversarial() {
        let patterns = [
            String(repeating: "(", count: 500) + String(repeating: "+)+", count: 500), String(repeating: "((a+)+", count: 1000),
        ]
        for pattern in patterns + [String(repeating: "(a|", count: 300) + "b"] {
            #expect(codes([pattern]) == ["error invalid-pattern /fields/0/validation/pattern"])
        }
    }

    @Test("patterns are scanned up to 1000 characters")
    func length() {
        let pattern = { (length: Int) in "(a+)+" + String(repeating: "b", count: length - 5) }
        #expect(codes([pattern(1000)]) == ["warning slow-pattern /fields/0/validation/pattern"])
        #expect(codes([pattern(1001)]).isEmpty)
    }
}

import Foundation
import Testing

@testable import FormhausCore

private func patternForm(_ patterns: [String]) -> JSONValue {
    let fields = patterns.enumerated().map { index, pattern -> JSONValue in
        ["key": .string("p\(index)"), "type": "text", "label": "P", "validation": ["pattern": .string(pattern)]]
    }
    return ["id": "f", "title": "F", "submit": ["label": "S"], "fields": .array(fields)]
}

private let letters = (0..<150).map { index in
    let start = 0x100 + index * 5
    return String(decoding: [UInt16(start), 0x2D, UInt16(start + 2)], as: UTF16.self)
}.joined()

private func codes(_ patterns: [String]) -> [String] {
    checkDefinition(patternForm(patterns)).map { "\($0.severity.rawValue) \($0.code.rawValue) \($0.path)" }
}

@Suite("Slow pattern warnings")
struct SlowPatternTests {
    @Test("adjacent repeated parts that overlap are slow")
    func adjacent() throws {
        let slow = [
            "^\\d*\\d*\\d*\\d*\\d*x$", "a*a*b", ".*.*x", "\\d+\\w+", "[a-c]+[c-e]*", "(?:a|b)*a{2,}", "x(?:\\s*\\s+)y",
            "^\\d+\\.?\\d*$", "a+b{0,3}a+", "\\d+(?:-)?\\d+",
        ]
        let fast = ["^\\d+-\\d+$", "[a-z]+@[a-z]+", "a*b*", "\\d*\\D*", "a?a?", "a+(?=a)a+", "\\(a*\\)a*"]
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
            #expect(codes([pattern]).filter { $0.hasPrefix("error") } == ["error invalid-pattern /fields/0/validation/pattern"])
        }
    }

    @Test("patterns are scanned up to 1000 characters and longer ones are reported")
    func length() {
        let pattern = { (length: Int) in "(a+)+" + String(repeating: "b", count: length - 5) }
        #expect(codes([pattern(1000)]) == ["warning slow-pattern /fields/0/validation/pattern"])
        #expect(codes([pattern(1001)]) == ["warning slow-pattern /fields/0/validation/pattern"])
        let long = checkDefinition(patternForm([String(repeating: "a", count: 1001)])).first
        #expect(long?.hint == "Shorten it to 1000 characters or less.")
    }

    @Test("edge patterns get the verdicts of core")
    func coreVerdicts() throws {
        let url = (Bundle.module.resourceURL ?? Bundle.module.bundleURL).appendingPathComponent("Fixtures/slow-patterns.json")
        let rows = try JSONValue(parsing: Data(contentsOf: url)).arrayValue ?? []
        #expect(rows.count > 700)
        for row in rows {
            let items = row.arrayValue ?? []
            let pattern = items.first?.stringValue ?? ""
            #expect(slowPattern(pattern).map { "\($0)" } == items[1].stringValue, "\(pattern)")
        }
    }

    @Test("a repeated group with a separator class that nothing else in it matches is not slow")
    func separatorClasses() {
        let patterns = [
            "^[A-Za-z]+([ '-][A-Za-z]+)*$", "^[A-Za-z]+(\\s[A-Za-z]+)*$", "^\\w+(?:\\s+\\w+)*$", "^[\\p{L}]+(?:[ '-][\\p{L}]+)*$",
            "^[\\p{L}0-9]+(?:[ &.,'()-]+[\\p{L}0-9]+)*$", "^[a-z0-9]+(?:[._-][a-z0-9]+)*@[a-z0-9]+(?:[.-][a-z0-9]+)*\\.[a-z]{2,}$",
            "^\\+?[0-9]{1,3}(?:[ -]?\\(?[0-9]{2,4}\\)?)?(?:[ -]?[0-9]{2,4}){2,3}$", "^#(?:[0-9a-fA-F]{3}){1,2}$", "^(?:\\d{3}-)+\\d{4}$",
            "^[A-Za-z\(letters)]+(?:[ '-][A-Za-z\(letters)]+)*$", "^[A-Za-z\(letters)]+(?:\\s+[A-Za-z\(letters)]+)*$",
        ]
        for pattern in patterns {
            #expect(pattern.utf16.count <= 1000 && slowPattern(pattern) == nil, "\(pattern)")
        }
    }

    @Test("nested and overlapping repeats are slow")
    func nestedAndOverlapping() {
        let patterns = [
            "^(a+)+$", "(\\w+\\s?)+", "^[A-Za-z]+(?:[ '-]?[A-Za-z]+)*$", "^(?:\\s+\\w*)*$", "^(?:\\d?){1,50}$", "^(?:\\w+|\\d+)+$",
            "^\\d+\\d+$", "^[\u{C0}-\u{FF}]+[\u{E0}-\u{FF}]+$", "^(?:[\\u00c0-\\u00ff]+\\s?)+$", "^(?:\\.a+)+(?:\\.a+)+$",
        ]
        let expected: [SlowPattern] = [.nested, .nested, .adjacent, .nested, .nested, .nested, .adjacent, .adjacent, .nested, .adjacent]
        #expect(patterns.map(slowPattern) == expected)
        #expect(slowPattern("^[A-Za-z\(letters)\(letters)\(letters)]+$") == .long)
    }
}

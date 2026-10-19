import Foundation
import Testing
@testable import FormhausCore

@Suite("Patterns match like JavaScript RegExp")
struct RegexTests {
    static let matches: [(String, String, Bool?)] = [
        ("", "x", true),
        ("^[\\w-.]+$", "a.b-c", true),
        ("(?<=a+)b", "aab", true),
        ("^\\1$", "\u{1}", true),
        ("^\\8$", "8", true),
        ("^\\101$", "A", true),
        ("^\\k$", "k", true),
        ("^\\01$", "\u{1}", true),
        ("^[\u{93E}\u{93F}\u{940}\u{941}]+$", "\u{93E}\u{93F}", true),
        ("^[\u{93E}\u{93F}\u{940}\u{941}]+$", "\u{93E}\u{915}", false),
        ("^.{1,3}$", "😀😀", false),
        ("^.{1,3}$", "😀", true),
        ("^[:digit:]$", "5", false),
        ("^[:digit:]$", ":", true),
        ("a++", "a", nil),
        ("(?i)abc", "ABC", nil),
        ("[😀-😂]", "😁", nil),
        ("(?=a)*a", "a", true),
        ("^\\d+$", "123", true),
        ("^\\d+$", "123\n", false),
        ("^\\d$", "\u{663}", false),
        ("^\\w$", "é", false),
        ("^a{$", "a{", true),
        ("^[^]$", "\n", true),
        ("^.$", "\n", false),
        ("^\\a$", "a", true),
        ("[(a+)]+", "+", true),
        ("[invalid(", "x", nil),
        ("(a", "a", nil),
    ]

    @Test("pattern test results", arguments: 0..<matches.count)
    func patternResult(index: Int) {
        let (source, text, expected) = Self.matches[index]
        let pattern = JSRegex(source)
        if let expected {
            #expect(pattern?.test(text) == expected, "\(source) on \(text)")
        } else {
            #expect(pattern == nil, "\(source) compiles")
        }
    }

    @Test("pattern source is never evaluated as code")
    func sourceIsData() {
        let source = "a/.test(\"\"), globalThis.pwned = 1, /a"
        #expect(JSRegex(source)?.test("a/Xtest\"\", globalThis.pwned = 1, /a") == true)
        #expect(JSRegex("\")+(1") == nil)
    }

    @Test("patterns compile and match from many threads")
    func concurrentUse() async {
        await withTaskGroup(of: Bool.self) { group in
            for index in 0..<64 {
                group.addTask { JSRegex("^x\(index % 300)$")?.test("x\(index % 300)") == true }
            }
            for await matched in group { #expect(matched) }
        }
    }
}

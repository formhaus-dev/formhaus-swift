import Testing

@testable import FormhausCore

private enum Kind {
    case forward
    case fromEnd
    case suffix
}

private func kind(_ source: String) throws -> Kind {
    switch try CompiledPattern(source).plan {
    case .forward: .forward
    case .fromEnd: .fromEnd
    case .suffix: .suffix
    }
}

private func forward(_ source: String, _ text: String) throws -> Bool? {
    try CompiledPattern("(?:" + source + ")(?=)").test(text)
}

private let texts: [String] = {
    var state: UInt64 = 5
    let alphabet: [Character] = ["a", "b", "1", "x", " ", ",", "😀", "\n"]
    let random = (0..<160).map { index in
        String(
            (0..<(index % 14)).map { _ -> Character in
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return alphabet[Int(state >> 33) % alphabet.count]
            })
    }
    return ["", "a", "b", "1", "ab", "ba", "a1", "x1", "aab", "abc1", "a😀", "😀", "foo", " foo", "afoo", "xb1b1"] + random
}()

@Suite("Reverse search")
struct RegexReverseTests {
    @Test(
        "end-anchored patterns run from the end",
        arguments: [
            "a$", "ab$", "(?:a|bc)$", "\\d+$", "(a+)+$", "[^]*a[^]{3}$", "x?$", "$", "(?:)$", "a*$", "\\b$", "a\\b$", "\\B$",
            "(?<=a)$", "(?<=ab)1$", "(?<!a)$", "(?<=^a?)b$", "^a$|b$", "(?:^|,)x$", "(?=a)\\w+$", "(?!1)..$", "(?:a$)+",
            "\\uD83D$", "\\uDE00$", ".$", "[\\uD800-\\uDBFF]$", "(?:b|$)$", "a$(?:z){0}",
        ])
    func fromEnd(source: String) throws {
        #expect(try kind(source) == .fromEnd)
        let pattern = try CompiledPattern(source)
        for text in texts { #expect(try pattern.test(text) == forward(source, text), "\(source) on \(text.debugDescription)") }
    }

    @Test(
        "patterns that end in a literal run back from each occurrence",
        arguments: [
            "[a-z]{0,40}1", "a[b-z]*1", "x[^]{0,20}1", "ab", "(?:ab|1)b", "\\bfoo", "(?<=a)1", "(?<!x)1", "[ab]*a[ab]{2}1", "(?:a|)1",
            "1(?:){0}", "x(?:1)",
        ])
    func suffix(source: String) throws {
        #expect(try kind(source) == .suffix)
        let pattern = try CompiledPattern(source)
        for text in texts { #expect(try pattern.test(text) == forward(source, text), "\(source) on \(text.debugDescription)") }
    }

    @Test(
        "other patterns keep the forward search",
        arguments: ["^a$", "(?m:a$)", "a$(?=)", "(a)\\1$", "(a)\\1", "a|b$", "foo\\b", "(?i:a)", "a$|b", "^(?:a|b)1"])
    func forwardOnly(source: String) throws {
        #expect(try kind(source) == .forward)
    }

    @Test("a reverse scan that reaches the previous occurrence falls back to a full search")
    func floorFallback() throws {
        let pattern = try CompiledPattern("x[^]{0,20}1")
        let text = String(repeating: "bb1", count: 3000)
        #expect(pattern.test(text + "x1") == true)
        #expect(pattern.test(text + "1") == false)
        #expect(pattern.test(text + "x" + String(repeating: "b", count: 30) + "1") == false)
        #expect(pattern.test("x" + text) == true)
    }

    @Test("large end-anchored repeats decide from the end")
    func largeRepeats() throws {
        let pattern = try CompiledPattern("[^]*a[^]{3900}$")
        let tail = String(repeating: "b", count: 3900)
        #expect(pattern.test(String(repeating: "b", count: 6000) + "a" + tail) == true)
        #expect(pattern.test(String(repeating: "a", count: 6000) + "b" + tail) == false)
        #expect(pattern.test("a" + tail.dropLast()) == false)
        let counted = try CompiledPattern("[a-z]{0,4001}1")
        #expect(counted.test(String(repeating: "b", count: 6000) + "1") == true)
        #expect(counted.test(String(repeating: "b", count: 6000) + "2") == false)
    }
}

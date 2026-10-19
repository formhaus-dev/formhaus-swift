import Foundation
import Testing

@testable import FormhausCore

private func randomText(_ count: Int, _ alphabet: [Character], seed: UInt64) -> String {
    var state = seed
    return String(
        (0..<count).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return alphabet[Int(state >> 33) % alphabet.count]
        })
}

@Suite("Native pattern engine regressions")
struct RegexRegressionTests {
    @Test("a reset automaton keeps its start state")
    func resetKeepsStart() throws {
        let pattern = try #require(JSRegex("[ab]*a[ab]{12}$"))
        _ = pattern.test(randomText(maxStringLength, ["a", "b"], seed: 7))
        #expect(pattern.test("a") == false)
        #expect(pattern.test("ab") == false)
        #expect(pattern.test("a" + String(repeating: "b", count: 12)) == true)
        #expect(pattern.test(String(repeating: "b", count: 13)) == false)
    }

    @Test("clearing many captures counts toward the step budget")
    func captureClearingBudget() throws {
        let pattern = try #require(JSRegex("(?:a|[]" + String(repeating: "()", count: 10000) + ")*\\1(?!)"))
        let started = Date()
        #expect(pattern.test(String(repeating: "a", count: maxStringLength - 1)) == nil)
        #expect(Date().timeIntervalSince(started) < 15)
    }

    @Test("unset duplicate groups in a backreference count toward the step budget")
    func backreferenceGroupsBudget() throws {
        let groups = String(repeating: "(?<n>a)|", count: 4000)
        let pattern = try #require(JSRegex("(?:" + groups + "b)(?:\\k<n>c)*$"))
        let started = Date()
        #expect(pattern.test("b" + String(repeating: "c", count: maxStringLength - 1)) == nil)
        #expect(Date().timeIntervalSince(started) < 15)
    }

    @Test(
        "duplicate group names follow V8 alternatives",
        arguments: [
            ("(?<n>)(?:(x)|y)(?:z|(?<n>a))", false),
            ("(?<n>a)(?:b|(?<n>c))", true),
            ("(?:(?<n>a)|(?<n>b))", true),
            ("(?<n>a)|(?:b|(?<n>c))", true),
            ("((?<n>a)|(?<n>b))(?:c|(?<n>d))", false),
            ("(?<n>x)|(?:(?<n>y)(?:z|(?<n>w)))", true),
        ])
    func duplicateNames(source: String, valid: Bool) {
        #expect((JSRegex(source) != nil) == valid, "\(source)")
    }

    @Test("nested lookarounds run in linear time")
    func nestedLookaroundsAreLinear() throws {
        let pattern = try #require(JSRegex("(?=(?!b)[^]*x)y(?:z|$)"))
        let started = Date()
        #expect(pattern.test(String(repeating: "y", count: maxStringLength - 1) + "x") == false)
        #expect(try #require(JSRegex("^(?=(?!b)[^]*x)y+x$")).test(String(repeating: "y", count: maxStringLength - 1) + "x") == true)
        #expect(Date().timeIntervalSince(started) < 0.5)
    }

    @Test("a pattern past the size limit fails closed")
    func sizeLimit() throws {
        let optional = (RegexCompiler.instructionLimit - 2) / 2
        #expect(try #require(JSRegex("a" + String(repeating: "b?", count: optional))).test("ab") == true)
        #expect(try #require(JSRegex("a" + String(repeating: "b?", count: optional + 1))).test("ab") == nil)
        let literal = String(repeating: "a", count: RegexCompiler.instructionLimit)
        #expect(try #require(JSRegex(literal)).test(literal) == nil)
        #expect(try #require(JSRegex(literal)).test("a") == false)
        #expect(try #require(JSRegex("(?:a{1000}){1000}")).test("aaaa") == false)
    }

    @Test("large counted repeats match every input up to the length limit")
    func largeCountedRepeats() throws {
        #expect(try #require(JSRegex("[a-z]{0,4001}1")).test(String(repeating: "b", count: 6000) + "1") == true)
        #expect(try #require(JSRegex("[a-z]{0,4001}1")).test(String(repeating: "b", count: 6000) + "2") == false)
        #expect(try #require(JSRegex("(?:x?){4001}y")).test("xay") == true)
        #expect(try #require(JSRegex("(?:a|b){4001}c")).test(String(repeating: "ab", count: 2001) + "c") == true)
        #expect(try #require(JSRegex("^(?:a{0,2}){2001}$")).test(String(repeating: "a", count: 4002)) == true)
    }

    @Test("automaton memory stays inside the pattern and global limits")
    func automatonMemory() throws {
        for offset in 0..<40 {
            let width = 300 - offset
            let compiled = try CompiledPattern("[^]*a[^]{\(width)}$")
            let text = randomText(1600, ["a", "b"], seed: UInt64(offset + 1))
            #expect(compiled.test(text) == (Array(text.utf16)[1600 - width - 1] == UInt16(ascii: "a")))
            #expect(compiled.test(String(text.prefix(width + 1))) == text.hasPrefix("a"))
            let bytes = try #require(compiled.automaton).inspect(\.bytes)
            #expect(bytes <= AutomatonMemory.patternLimit)
            #expect(AutomatonMemory.reservedTotal <= AutomatonMemory.globalLimit)
        }
    }

    @Test("threads share automatons without changing results")
    func sharedAutomatons() async throws {
        let sources = ["[ab]*a[ab]{12}$", "[^]*a[^]{100}$", "(?=[ab]*a[ab]{10}$)[ab]+", "(?<=a[ab]{9})b$", "^(?:a|b)*a(?:a|b){11}$"]
        let texts = (0..<6).map { randomText($0 % 2 == 0 ? 20 : 800, ["a", "b"], seed: UInt64($0 + 11)) }
        let expected = try sources.map { source in try texts.map { try CompiledPattern(source).test($0) } }
        let patterns = try sources.map { try #require(JSRegex($0)) }
        let mismatches = await withTaskGroup(of: Int.self) { group in
            for worker in 0..<8 {
                group.addTask {
                    var mismatches = 0
                    for round in 0..<3 {
                        for index in patterns.indices {
                            let pattern = (index + worker + round) % patterns.count
                            for (text, result) in zip(texts, expected[pattern]) where patterns[pattern].test(text) != result {
                                mismatches += 1
                            }
                        }
                    }
                    return mismatches
                }
            }
            return await group.reduce(0, +)
        }
        #expect(mismatches == 0)
    }

    @Test(
        "the required literal search finds every occurrence",
        arguments: [
            ("x\u{161}abcab", true), ("abcaabcab", true), ("abcab", true), ("abca", false), ("\u{161}bcab", false), ("abcxabcab!", true),
        ])
    func requiredLiteral(text: String, expected: Bool) throws {
        #expect(try #require(JSRegex("abcab")).test(text) == expected)
        #expect(try #require(JSRegex("[a-z]*abcab")).test(text) == expected)
    }

    @Test(
        "counted repeats larger than any input still match",
        arguments: [
            ("^.{0,16384}$", true), ("^[\\s\\S]{0,65535}$", true), ("^[^<>]{0,20000}$", true), ("^.{1,50000}$", true),
            ("^(?:[a-z]{2,8}-){0,4000}$", false), ("^(\\w{1,200} ?){1,200}$", true),
        ])
    func repeatsBeyondTheInputLimit(source: String, expected: Bool) throws {
        let pattern = try #require(JSRegex(source))
        #expect(pattern.test("hello world") == expected)
        if !source.hasPrefix("^(\\w") { #expect(pattern.test(String(repeating: "a", count: maxStringLength + 1)) == nil) }
    }

    @Test("nested counted repeats find a match on long input")
    func nestedCountedRepeats() throws {
        let pattern = try #require(JSRegex("^(\\w{1,200} ?){1,200}$"))
        #expect(pattern.test(String(repeating: "a", count: maxStringLength - 1) + "b") == true)
    }
}

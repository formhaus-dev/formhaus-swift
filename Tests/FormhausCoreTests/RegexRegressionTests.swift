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
        #expect(Date().timeIntervalSince(started) < 2)
    }

    @Test("unset duplicate groups in a backreference count toward the step budget")
    func backreferenceGroupsBudget() throws {
        let groups = String(repeating: "(?<n>a)|", count: 4000)
        let pattern = try #require(JSRegex("(?:" + groups + "b)(?:\\k<n>c)*$"))
        let started = Date()
        #expect(pattern.test("b" + String(repeating: "c", count: maxStringLength - 1)) == nil)
        #expect(Date().timeIntervalSince(started) < 2)
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
        #expect(try #require(JSRegex(String(repeating: "a", count: RegexCompiler.instructionLimit))).test("a") == nil)
    }
}

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
        let pattern = try #require(JSRegex("[ab]*a[ab]{12}$(?=)"))
        _ = pattern.test(randomText(maxStringLength, ["a", "b"], seed: 7))
        #expect(pattern.test("a") == false)
        #expect(pattern.test("ab") == false)
        #expect(pattern.test("a" + String(repeating: "b", count: 12)) == true)
        #expect(pattern.test(String(repeating: "b", count: 13)) == false)
    }

    @Test("clearing many captures counts toward the step budget", arguments: Load.sizes(1000, heavy: 10000))
    func captureClearingBudget(groups: Int) throws {
        let pattern = try #require(JSRegex("(?:a|[]" + String(repeating: "()", count: groups) + ")*\\1(?!)"))
        let text = String(repeating: "a", count: maxStringLength - 1)
        StepBudget.$backtrackingLimit.withValue(groups * 100) { #expect(pattern.test(text) == nil) }
    }

    @Test("unset duplicate groups in a backreference count toward the step budget", arguments: Load.sizes(400, heavy: 4000))
    func backreferenceGroupsBudget(count: Int) throws {
        let groups = String(repeating: "(?<n>a)|", count: count)
        let pattern = try #require(JSRegex("(?:" + groups + "b)(?:\\k<n>c)*$"))
        let text = "b" + String(repeating: "c", count: maxStringLength - 1)
        StepBudget.$backtrackingLimit.withValue(count * 250) { #expect(pattern.test(text) == nil) }
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
        let unanchored = try #require(JSRegex("(?=(?!b)[^]*x)y(?:z|$)"))
        let anchored = try #require(JSRegex("^(?=(?!b)[^]*x)y+x$"))
        let long = String(repeating: "y", count: maxStringLength - 1) + "x"
        let short = String(repeating: "y", count: maxStringLength / 8 - 1) + "x"
        #expect(unanchored.test(long) == false)
        #expect(anchored.test(long) == true)
        #expect(unanchored.test(short) == false)
        #expect(anchored.test(short) == true)
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

    @Test("large counted repeats match every input up to the length limit", arguments: Load.sizes(401, heavy: 4001))
    func largeCountedRepeats(count: Int) throws {
        let half = (count + 1) / 2
        let long = String(repeating: "b", count: count * 3 / 2)
        #expect(try #require(JSRegex("[a-z]{0,\(count)}1")).test(long + "1") == true)
        #expect(try #require(JSRegex("[a-z]{0,\(count)}1")).test(long + "2") == false)
        #expect(try #require(JSRegex("(?:x?){\(count)}y")).test("xay") == true)
        #expect(try #require(JSRegex("(?:a|b){\(count)}c")).test(String(repeating: "ab", count: half) + "c") == true)
        #expect(try #require(JSRegex("^(?:a{0,2}){\(half)}$")).test(String(repeating: "a", count: 2 * half)) == true)
    }

    @Test("automaton memory stays inside the pattern and global limits", arguments: Load.sizes(4, heavy: 40))
    func automatonMemory(offsets: Int) throws {
        for offset in 0..<offsets {
            let width = 300 - offset
            let compiled = try CompiledPattern("[^]*a[^]{\(width)}$(?=)")
            let text = randomText(1600, ["a", "b"], seed: UInt64(offset + 1))
            #expect(compiled.test(text) == (Array(text.utf16)[1600 - width - 1] == UInt16(ascii: "a")))
            #expect(compiled.test(String(text.prefix(width + 1))) == text.hasPrefix("a"))
            let bytes = try #require(compiled.automaton).bytes
            #expect(bytes <= AutomatonMemory.patternLimit)
            #expect(AutomatonMemory.reservedTotal <= AutomatonMemory.globalLimit)
        }
    }

    private static let pools: [(round: Int, count: Int, limit: Int)] =
        Load.heavy ? (0..<3).map { ($0, 50, AutomatonMemory.globalLimit) } : [(0, 8, 4 << 20)]

    @Test("a full memory pool reclaims states from automatons that sat idle", arguments: pools)
    func reclaimIdleAutomatons(round: Int, count: Int, limit: Int) throws {
        let pool = MemoryPool(limit: limit)
        try MemoryPool.$current.withValue(pool) {
            let letter = ["c", "d", "e"][round]
            let patterns = try (0..<count).map { try CompiledPattern("[^]*\(letter)[^]{\(300 - $0)}$(?=)") }
            for (index, pattern) in patterns.enumerated() {
                _ = pattern.test(randomText(1300, [Character(letter), "b"], seed: UInt64(index + 1)))
                #expect(AutomatonMemory.reservedTotal <= pool.limit)
            }
            #expect(try #require(patterns.last?.automaton).bytes > AutomatonMemory.patternLimit / 2)
            let fresh = try CompiledPattern("^[a-z]+@[a-z]+\\.\(letter)[a-z]{2,}$")
            #expect(fresh.test("ada@example.\(letter)om") == true)
            #expect(try #require(fresh.automaton).bytes > 0)
        }
    }

    @Test("threads share automatons without changing results", arguments: Load.sizes(1, heavy: 12))
    func sharedAutomatons(passes: Int) async throws {
        let sources = [
            "[ab]*a[ab]{12}$", "[ab]*a[ab]{12}$(?=)", "[^]*a[^]{100}$", "(?=[ab]*a[ab]{10}$)[ab]+", "(?<=a[ab]{9})b$",
            "^(?:a|b)*a(?:a|b){11}$",
        ]
        let texts = (0..<6).map { randomText($0 % 2 == 0 ? 20 : 800, ["a", "b"], seed: UInt64($0 + 11)) }
        let expected = try sources.map { source in try texts.map { try CompiledPattern(source).test($0) } }
        let patterns = try sources.map { try #require(JSRegex($0)) }
        let mismatches = await withTaskGroup(of: Int.self) { group in
            for worker in 0..<8 {
                group.addTask {
                    var mismatches = 0
                    for round in 0..<passes {
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

    @Test("nested empty repeats with backreferences fail closed on short values")
    func nestedEmptyRepeatsFailClosed() throws {
        let source = "(?:((\\1{0,1}\\1[\\s\\S]?){2}(?i:\\1[^a]{0,1}|\\uFEFF{1,}?|\\b\\1{1,3}?\\b){0})*(?i:(?:)K|))+[ab]"
        let pattern = try #require(JSRegex(source))
        StepBudget.$backtrackingLimit.withValue(Load.heavy ? StepBudget.backtrackingLimit : 50_000) {
            #expect(pattern.test("a\u{212A}-_\u{FEFF}\u{E9}x1") == nil)
        }
    }

    @Test("the pattern cache stays inside its byte limit")
    func patternCacheBytes() throws {
        let cache = PatternCache(byteLimit: 4 << 20)
        let large = (0..<12).map { "a\($0)" + String(repeating: "b?", count: 16000) }
        for source in large {
            #expect(cache.pattern(source)?.test("a") == false)
            #expect(cache.bytes <= 4 << 20)
        }
        #expect(cache.bytes > 2 << 20)
        let small = try #require(cache.pattern("^ok$"))
        #expect(small.test("ok") == true)
        let huge = "x" + String(repeating: "y?", count: 100_000)
        let before = cache.bytes
        #expect(cache.pattern(huge)?.test("xy") == true)
        #expect(cache.bytes == before)
    }
}

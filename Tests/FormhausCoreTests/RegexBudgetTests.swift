import Testing

@testable import FormhausCore

private let heavy = "^(?:a?b?c?d?e?f?g?h?){10000}$"
private let heavyText = String(repeating: "a", count: 9990) + "!"

@Suite("Pattern budgets and cache keys")
struct RegexBudgetTests {
    @Test("canonically equivalent patterns keep separate cache entries")
    func exactCacheKeys() throws {
        let cache = PatternCache()
        #expect(cache.pattern("^[^e\u{301}]+$")?.test("x") == true)
        #expect(cache.pattern("^[^\u{E9}]+$")?.test("\u{E9}") == false)
        #expect(cache.pattern("^[^e\u{301}]+$")?.test("\u{E9}") == true)
        #expect(JSRegex("^[^e\u{301}]+$")?.test("x") == true)
        #expect(JSRegex("^[^\u{E9}]+$")?.test("\u{E9}") == false)
    }

    @Test("a linear match stops at the step limit and fails closed")
    func linearLimit() throws {
        let pattern = try CompiledPattern(heavy)
        StepBudget.$backtrackingLimit.withValue(Load.heavy ? StepBudget.backtrackingLimit : 4_000_000) {
            #expect(pattern.test(heavyText) == nil)
            #expect(pattern.test("abcdefgh") == true)
        }
    }

    @Test("one budget covers every pattern in a call")
    func callBudget() throws {
        let pattern = try CompiledPattern(heavy)
        let simple = try CompiledPattern("^a+$")
        CallBudget.$current.withValue(CallBudget(limit: 200_000)) {
            #expect(simple.test("aaa") == true)
            #expect(pattern.test(heavyText) == nil)
            #expect(simple.test("aaa") == nil)
        }
        #expect(simple.test("aaa") == true)
    }

    @Test("a submission fails closed on every field once its budget runs out")
    func submissionBudget() throws {
        let fields: [JSONValue] = (0..<3).map { index in
            ["key": .string("f\(index)"), "type": "text", "label": "F", "validation": ["pattern": .string(heavy)]]
        }
        let definition: JSONValue = ["id": "p", "submit": ["label": "S"], "fields": .array(fields)]
        let values: JSONValue = ["f0": .string(heavyText), "f1": "abc", "f2": "abc"]
        let result = try StepBudget.$backtrackingLimit.withValue(Load.heavy ? StepBudget.backtrackingLimit : 4_000_000) {
            try validateSubmission(definition, values)
        }
        #expect(result.errors["f0"] != nil)
        #expect(result.errors["f1"] == nil)
        let exhausted = try CallBudget.$current.withValue(CallBudget(limit: 0)) { try validateSubmission(definition, values) }
        #expect(exhausted.errors["f1"] != nil)
    }
}

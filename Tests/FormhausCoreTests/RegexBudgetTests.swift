import Testing

@testable import FormhausCore

private let heavy = "^(?:a?b?c?d?e?f?g?h?){10000}$"
private let heavyText = String(repeating: "a", count: 9990) + "!"
private let wide = "^[a-h]{0,10000}[a-h]{0,10000}$"

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
            ["key": .string("f\(index)"), "type": "text", "label": "F", "validation": ["pattern": .string(wide)]]
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

    @Test("public validators run in their own budget")
    func publicBudgets() throws {
        let probe: Validators = ["probe": { _, _ in CallBudget.current == nil ? "outside" : nil }]
        let field: JSONValue = ["key": "a", "type": "text", "label": "A", "validation": ["validator": "probe"]]
        let nodes = try FormDefinition(json: ["id": "p", "submit": ["label": "S"], "fields": [field]]).fields ?? []
        let first = try #require(nodes.first?.field)
        #expect(validateFieldValue(first, "x", [:], options: ValidateOptions(validators: probe)) == nil)
        #expect(validateFields(nodes, ["a": "x"], options: ValidateOptions(validators: probe)).isEmpty)
    }

    @Test("one validation tests at most 10,000 values against patterns")
    func patternTestLimit() throws {
        let limit = CallBudget.patternTestLimit
        let fields: [JSONValue] = (0...limit).map { index in
            ["key": .string("f\(index)"), "type": "text", "label": "F", "validation": ["pattern": "^a$"]]
        }
        let definition = try FormDefinition(json: ["id": "p", "submit": ["label": "S"], "fields": .array(fields)])
        let nodes = definition.fields ?? []
        var values = JSONObject()
        for index in 0...limit { values["f\(index)"] = "a" }
        for _ in 0..<2 {
            #expect(validateFields(nodes, values) == ["f\(limit)": "Invalid format"])
        }
        let field = try #require(nodes.first?.field)
        #expect((0...limit).allSatisfy { _ in validateFieldValue(field, "a", values) == nil })
    }
}

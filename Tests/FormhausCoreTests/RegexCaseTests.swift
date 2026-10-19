import Foundation
import Testing

@testable import FormhausCore

private struct RegexCaseFile: Decodable {
    let node: String
    let counts: [String: Int]
    let cases: [RegexCase]
}

private struct RegexCase: Decodable {
    let pattern: String
    let input: String
    let result: Expected
    let kind: String
}

private enum Expected: Decodable, Equatable {
    case match(Bool)
    case syntaxError

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .match(value)
        } else {
            self = .syntaxError
        }
    }
}

@Suite("Patterns match like node RegExp")
struct RegexCaseTests {
    private static func load() throws -> RegexCaseFile {
        let root = Bundle.module.resourceURL ?? Bundle.module.bundleURL
        let data = try Data(contentsOf: root.appendingPathComponent("Fixtures/regex/cases.json"))
        return try JSONDecoder().decode(RegexCaseFile.self, from: data)
    }

    @Test("every generated case matches the recorded node result")
    func generatedCases() throws {
        let file = try Self.load()
        #expect(file.cases.count == file.counts.values.reduce(0, +))
        var failures: [String] = []
        for item in file.cases {
            let pattern = JSRegex(item.pattern)
            let actual: Expected? = pattern == nil ? .syntaxError : pattern?.test(item.input).map(Expected.match)
            if actual != item.result {
                failures.append(
                    "\(item.kind) \(item.pattern.debugDescription) on \(item.input.debugDescription): \(String(describing: actual))")
            }
        }
        #expect(
            failures.isEmpty,
            "\(failures.count) of \(file.cases.count) cases differ from node \(file.node):\n\(failures.prefix(40).joined(separator: "\n"))")
    }
}

@Suite("Native pattern engine limits")
struct RegexLimitTests {
    @Test("linear patterns stay fast on pathological input")
    func pathologicalInput() throws {
        let text = String(repeating: "a", count: maxStringLength - 1) + "!"
        let started = Date()
        for source in ["(a+)+$", "(a|aa)+$", "^(a+)+$", "(.*a){20}$"] {
            #expect(try #require(JSRegex(source)).test(text) == false, "\(source)")
        }
        #expect(try #require(JSRegex("(x+x+)+y")).test(String(repeating: "x", count: maxStringLength)) == false)
        #expect(Date().timeIntervalSince(started) < 2)
    }

    @Test("a backtracking match that runs out of steps fails closed")
    func stepBudget() throws {
        let pattern = try #require(JSRegex("^(a|a)*\\1b$"))
        #expect(pattern.test(String(repeating: "a", count: 40) + "cb") == nil)
        #expect(pattern.test("aab") == true)
    }

    @Test("lookarounds without backreferences are memoized")
    func memoizedLookaround() throws {
        let pattern = try #require(JSRegex("^(?=(?:a|a)*b)(?:a|a)*c$"))
        #expect(pattern.test(String(repeating: "a", count: maxStringLength - 1) + "c") == false)
    }

    @Test("deep nesting compiles on a secondary thread")
    func deepNesting() async {
        let depth = RegexParser.maxDepth - 1
        let source = String(repeating: "(?:a|", count: depth) + "b" + String(repeating: ")", count: depth)
        let tooDeep = String(repeating: "(", count: RegexParser.maxDepth + 1) + String(repeating: ")", count: RegexParser.maxDepth + 1)
        let results = await Task.detached { (JSRegex(source)?.test("b"), JSRegex(tooDeep) == nil) }.value
        #expect(results.0 == true)
        #expect(results.1)
    }

    @Test("the cache keeps working past its limit")
    func cacheEviction() {
        for index in 0..<(PatternCache.limit + 50) { #expect(JSRegex("^p\(index)$")?.test("p\(index)") == true) }
        #expect(JSRegex("^p0$")?.test("p0") == true)
    }
}

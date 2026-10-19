import Foundation
import Testing

@testable import FormhausCore

@Suite("JSON parser")
struct JSONParserTests {
    private func onSmallStack(_ body: @escaping @Sendable () -> String) async -> String {
        await withCheckedContinuation { done in
            let thread = Thread { done.resume(returning: body()) }
            thread.stackSize = 512 * 1024
            thread.start()
        }
    }

    private func nested(_ depth: Int) -> String {
        String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
    }

    @Test("200,000 nested arrays fail cleanly on a background thread")
    func deepNesting() async {
        let text = nested(200_000)
        let outcome = await onSmallStack {
            do throws(JSONParseError) {
                _ = try JSONValue(parsing: text)
                return "parsed"
            } catch {
                return error.reason
            }
        }
        #expect(outcome == "nesting deeper than 512 levels")
    }

    @Test("the deepest accepted document parses, compares, prints and frees on a background thread")
    func deepestAccepted() async {
        let text = nested(JSONValue.maxNestingDepth)
        let outcome = await onSmallStack {
            guard var value = try? JSONValue(parsing: text), let copy = try? JSONValue(parsing: text) else { return "failed" }
            let printed = jsonStringify(value)
            let same = value == copy && value.hashValue == copy.hashValue
            value = .null
            return same && printed == text ? "ok" : "mismatch"
        }
        #expect(outcome == "ok")
        #expect(throws: JSONParseError.self) { try JSONValue(parsing: "{\"a\":\(nested(JSONValue.maxNestingDepth))}") }
    }

    @Test("lone surrogates are rejected", arguments: [#""\uD800""#, #""\uDC00""#, #""\uD800A""#, #""\uD800x""#, #""\uDBFF\uDBFF""#])
    func loneSurrogates(text: String) {
        #expect(throws: JSONParseError.self) { try JSONValue(parsing: text) }
    }

    @Test("escaped surrogate pairs and malformed escapes")
    func escapes() throws {
        #expect(try JSONValue(parsing: #""😀""#) == "😀")
        #expect(throws: JSONParseError.self) { try JSONValue(parsing: #""\u+123""#) }
        #expect(throws: JSONParseError.self) { try JSONValue(parsing: #""\u12""#) }
    }

    @Test("parser keeps key order and own __proto__ keys")
    func keyOrder() throws {
        let value = try JSONValue(parsing: #"{"b":1,"__proto__":{"x":true},"a":[null,"é😀"],"b":2}"#)
        let object = try #require(value.objectValue)
        #expect(object.keys == ["b", "__proto__", "a"])
        #expect(object["b"] == 2)
        #expect(object["a"] == .array([.null, .string("é😀")]))
        #expect(throws: JSONParseError.self) { try JSONValue(parsing: "{\"a\":01}") }
        #expect(throws: JSONParseError.self) { try JSONValue(parsing: "[1,]") }
        #expect(throws: JSONParseError.self) { try JSONValue(parsing: "{\"a\":1,}") }
        #expect(throws: JSONParseError.self) { try JSONValue(parsing: "[1] x") }
        #expect(try JSONValue(parsing: " [ { } , [ ] , -0.5e1 ] ") == [[:], [], -5])
    }
}

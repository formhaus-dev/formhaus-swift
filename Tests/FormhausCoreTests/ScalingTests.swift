import Foundation
import Testing

@testable import FormhausCore

@Suite("Large inputs scale linearly")
struct ScalingTests {
    private func growth(_ runs: Int = 3, short: () -> Void, long: () -> Void) -> Double {
        let clock = ContinuousClock()
        var fastest = (short: Duration.seconds(600), long: Duration.seconds(600))
        for _ in 0..<runs {
            fastest.short = min(fastest.short, clock.measure(short))
            fastest.long = min(fastest.long, clock.measure(long))
        }
        return fastest.long / fastest.short
    }

    private func array(_ count: Int) -> String {
        "[" + Array(repeating: "1", count: count).joined(separator: ",") + "]"
    }

    private func object(_ count: Int) -> String {
        let pairs = (0..<count).reversed().map { #""\#($0)":1,"k\#($0)":1"# }
        return "{" + pairs.joined(separator: ",") + "}"
    }

    private func form(_ count: Int) -> (definition: JSONValue, values: JSONValue) {
        var fields: [JSONValue] = []
        var values = JSONObject()
        for index in 0..<count {
            var field: JSONObject = ["key": .string("f\(index)"), "type": "text", "label": "F"]
            if index > 0 { field["show"] = [["field": .string("f\(index - 1)"), "notEmpty": true]] }
            fields.append(.object(field))
            values["f\(index)"] = "v"
        }
        return (["id": "f", "title": "F", "submit": ["label": "S"], "fields": .array(fields)], .object(values))
    }

    @Test("a 200k-element array parses to every element")
    func largeArray() throws {
        let items = try #require(JSONValue(parsing: array(200_000)).arrayValue)
        #expect(items.count == 200_000)
        #expect(items.allSatisfy { $0 == 1 })
    }

    @Test("80k descending numeric keys parse in ascending order before named keys")
    func descendingKeys() throws {
        let object = try #require(JSONValue(parsing: self.object(80_000)).objectValue)
        #expect(object.keys == (0..<80_000).map(String.init) + (0..<80_000).reversed().map { "k\($0)" })
        #expect(object["79999"] == 1)
    }

    @Test("a million array elements parse in linear time", .heavy)
    func arrays() throws {
        let short = array(125_000)
        let long = array(1_000_000)
        #expect(growth(short: { _ = try? JSONValue(parsing: short) }, long: { _ = try? JSONValue(parsing: long) }) < 32)
    }

    @Test("a hundred thousand object keys parse in linear time", .heavy)
    func objects() throws {
        let short = object(6_250)
        let long = object(50_000)
        #expect(growth(short: { _ = try? JSONValue(parsing: short) }, long: { _ = try? JSONValue(parsing: long) }) < 32)
    }

    @Test("parsed objects keep JavaScript key order and the first position of duplicate keys")
    func parsedOrder() throws {
        let object = try #require(JSONValue(parsing: #"{"b":1,"2":1,"a":1,"10":1,"01":1,"2":3,"4294967295":1,"1":1}"#).objectValue)
        #expect(object.keys == ["1", "2", "10", "b", "a", "01", "4294967295"])
        #expect(object["2"] == 3)
        var copy = object
        copy["0"] = 1
        copy["c"] = 1
        #expect(copy.keys == ["0", "1", "2", "10", "b", "a", "01", "4294967295", "c"])
    }

    @Test("2,000 chained fields validate without errors")
    func manyFields() throws {
        let form = form(2_000)
        let result = try validateSubmission(form.definition, form.values)
        #expect(result.errors.isEmpty)
        #expect(result.values.count == 2_000)
    }

    @Test("validateSubmission scales linearly with the field count", .heavy)
    func submissions() {
        let short = form(250)
        let long = form(2_000)
        let ratio = growth(
            short: { _ = try? validateSubmission(short.definition, short.values) },
            long: { _ = try? validateSubmission(long.definition, long.values) })
        #expect(ratio < 32)
    }

    @MainActor
    @Test("defaultItems without maxLength stops at 100 items", arguments: [(1e6, 100), (2, 2)] as [(Double, Int)])
    func defaultItems(count: Double, expected: Int) throws {
        let group: JSONValue = [
            "key": "g", "type": "group", "label": "G", "defaultItems": .number(count),
            "fields": [["key": "a", "type": "text", "label": "A"]],
        ]
        let definition: JSONValue = ["id": "f", "title": "F", "submit": ["label": "S"], "fields": [group]]
        let engine = try FormEngine(definition: definition)
        #expect(engine.values["g"]?.arrayValue?.count == expected)
    }
}

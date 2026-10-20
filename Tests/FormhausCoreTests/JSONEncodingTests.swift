import FormhausCore
import Foundation
import Testing

@Suite("JSON encoding")
struct JSONEncodingTests {
    @Test("parse, encode and parse again gives the same value")
    func roundTrip() throws {
        let text = #"{"b":[1,2.5,-3,null,true,false],"a":{"x":"y","n":{}},"s":"line\nbreak \"q\" \\","e":[]}"#
        let value = try JSONValue(parsing: text)
        #expect(try JSONValue(parsing: value.jsonString()) == value)
        #expect(try JSONValue(parsing: value.jsonData()) == value)
        #expect(value.jsonString() == text)
    }

    @Test("numbers format like JSON.stringify")
    func numbers() {
        let cases: [(Double, String)] = [
            (1e21, "1e+21"), (1e20, "100000000000000000000"), (0.1 + 0.2, "0.30000000000000004"),
            (-0.0, "0"), (3, "3"), (-12, "-12"), (1.5, "1.5"), (1e-7, "1e-7"), (0.000001, "0.000001"),
            (5e-324, "5e-324"), (.nan, "null"), (.infinity, "null"), (-.infinity, "null"),
        ]
        for (number, expected) in cases {
            #expect(JSONValue.number(number).jsonString() == expected)
        }
    }

    @Test("strings escape per RFC 8259")
    func escapes() throws {
        let text = "\"\\/\u{08}\u{0C}\n\r\t\u{01}\u{1F}\u{7F}é😀\u{2028}"
        let encoded = JSONValue.string(text).jsonString()
        #expect(encoded == "\"\\\"\\\\/\\b\\f\\n\\r\\t\\u0001\\u001f\u{7F}é😀\u{2028}\"")
        #expect(try JSONValue(parsing: encoded) == .string(text))
    }

    @Test("replacement characters stay valid UTF-8")
    func lossyScalars() throws {
        let text = String(String.UnicodeScalarView([Unicode.Scalar(0xFFFD), "A"].compactMap { $0 }))
        let data = JSONValue.string(text).jsonData()
        #expect(String(bytes: data, encoding: .utf8) != nil)
        #expect(try JSONValue(parsing: data) == .string(text))
    }

    @Test("integer-like keys come first in numeric order")
    func keyOrder() throws {
        var object = JSONObject()
        for key in ["b", "10", "a", "2", "01"] { object[key] = .bool(true) }
        #expect(object.jsonString() == #"{"2":true,"10":true,"b":true,"a":true,"01":true}"#)
        let parsed = try JSONValue(parsing: #"{"b":1,"10":2,"2":3}"#)
        #expect(parsed.jsonString() == #"{"2":3,"10":2,"b":1}"#)
    }

    @Test("JSONObject and JSONValue encode the same bytes")
    func objectMatchesValue() {
        let object: JSONObject = ["email": "a@b.c", "age": 30, "tags": ["x", nil]]
        #expect(object.jsonString() == #"{"email":"a@b.c","age":30,"tags":["x",null]}"#)
        #expect(object.jsonData() == JSONValue.object(object).jsonData())
    }

    @Test("nested arrays encode to matching brackets")
    func deepNesting() {
        var value = JSONValue.null
        for _ in 0..<300 { value = .array([value]) }
        #expect(value.jsonString().count == 604)
    }

    @Test("Codable round trip")
    func codable() throws {
        struct Envelope: Codable, Equatable {
            let id: Int
            let values: JSONValue
        }
        let values = try JSONValue(parsing: #"{"a":[1,2.5,"x",null,true],"b":{"c":false},"d":""}"#)
        let envelope = Envelope(id: 7, values: values)
        let data = try JSONEncoder().encode(envelope)
        #expect(try JSONDecoder().decode(Envelope.self, from: data) == envelope)
        #expect(try JSONDecoder().decode(JSONValue.self, from: values.jsonData()) == values)
        #expect(try JSONValue(parsing: JSONEncoder().encode(values)) == values)
    }

    @Test("decoding keeps booleans and numbers apart")
    func decodeScalars() throws {
        let decoded = try JSONDecoder().decode(JSONValue.self, from: Data("[true,1,0,false,\"1\"]".utf8))
        #expect(decoded == [true, 1, 0, false, "1"])
    }
}

import Foundation

public struct JSONParseError: Error, Sendable, CustomStringConvertible {
    public let offset: Int
    public let reason: String

    public var description: String { "Invalid JSON at byte \(offset): \(reason)" }
}

extension JSONValue {
    public init(parsing text: String) throws(JSONParseError) {
        try self.init(parsing: Data(text.utf8))
    }

    public init(parsing data: Data) throws(JSONParseError) {
        var parser = JSONParser(bytes: [UInt8](data))
        self = try parser.parseDocument()
    }
}

private struct JSONParser {
    let bytes: [UInt8]
    var index = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func parseDocument() throws(JSONParseError) -> JSONValue {
        let value = try parseValue()
        skipWhitespace()
        guard index == bytes.count else { throw fail("unexpected trailing content") }
        return value
    }

    func fail(_ reason: String) -> JSONParseError {
        JSONParseError(offset: index, reason: reason)
    }

    mutating func skipWhitespace() {
        while index < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[index]) { index += 1 }
    }

    mutating func parseValue() throws(JSONParseError) -> JSONValue {
        skipWhitespace()
        guard index < bytes.count else { throw fail("unexpected end of input") }
        switch bytes[index] {
        case UInt8(ascii: "{"): return .object(try parseObject())
        case UInt8(ascii: "["): return .array(try parseArray())
        case UInt8(ascii: "\""): return .string(try parseString())
        case UInt8(ascii: "t"): return try literal("true", .bool(true))
        case UInt8(ascii: "f"): return try literal("false", .bool(false))
        case UInt8(ascii: "n"): return try literal("null", .null)
        default: return .number(try parseNumber())
        }
    }

    mutating func literal(_ word: String, _ value: JSONValue) throws(JSONParseError) -> JSONValue {
        let expected = Array(word.utf8)
        guard index + expected.count <= bytes.count, Array(bytes[index..<index + expected.count]) == expected else {
            throw fail("unexpected token")
        }
        index += expected.count
        return value
    }

    mutating func parseObject() throws(JSONParseError) -> JSONObject {
        index += 1
        var object = JSONObject()
        skipWhitespace()
        if index < bytes.count, bytes[index] == UInt8(ascii: "}") {
            index += 1
            return object
        }
        while true {
            skipWhitespace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else { throw fail("expected a property name") }
            let key = try parseString()
            skipWhitespace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else { throw fail("expected ':'") }
            index += 1
            object[key] = try parseValue()
            skipWhitespace()
            guard index < bytes.count else { throw fail("unterminated object") }
            if bytes[index] == UInt8(ascii: ",") {
                index += 1
                continue
            }
            guard bytes[index] == UInt8(ascii: "}") else { throw fail("expected ',' or '}'") }
            index += 1
            return object
        }
    }

    mutating func parseArray() throws(JSONParseError) -> [JSONValue] {
        index += 1
        var items: [JSONValue] = []
        skipWhitespace()
        if index < bytes.count, bytes[index] == UInt8(ascii: "]") {
            index += 1
            return items
        }
        while true {
            items.append(try parseValue())
            skipWhitespace()
            guard index < bytes.count else { throw fail("unterminated array") }
            if bytes[index] == UInt8(ascii: ",") {
                index += 1
                continue
            }
            guard bytes[index] == UInt8(ascii: "]") else { throw fail("expected ',' or ']'") }
            index += 1
            return items
        }
    }

    mutating func parseString() throws(JSONParseError) -> String {
        index += 1
        var units: [UInt16] = []
        while true {
            guard index < bytes.count else { throw fail("unterminated string") }
            let byte = bytes[index]
            if byte == UInt8(ascii: "\"") {
                index += 1
                return String(decoding: units, as: UTF16.self)
            }
            if byte < 0x20 { throw fail("control character in string") }
            if byte == UInt8(ascii: "\\") {
                units.append(contentsOf: try parseEscape())
                continue
            }
            let start = index
            while index < bytes.count, bytes[index] != UInt8(ascii: "\""), bytes[index] != UInt8(ascii: "\\"), bytes[index] >= 0x20 {
                index += 1
            }
            units.append(contentsOf: String(decoding: bytes[start..<index], as: UTF8.self).utf16)
        }
    }

    mutating func parseEscape() throws(JSONParseError) -> [UInt16] {
        index += 1
        guard index < bytes.count else { throw fail("unterminated escape") }
        let byte = bytes[index]
        index += 1
        switch byte {
        case UInt8(ascii: "\""): return [0x22]
        case UInt8(ascii: "\\"): return [0x5C]
        case UInt8(ascii: "/"): return [0x2F]
        case UInt8(ascii: "b"): return [0x08]
        case UInt8(ascii: "f"): return [0x0C]
        case UInt8(ascii: "n"): return [0x0A]
        case UInt8(ascii: "r"): return [0x0D]
        case UInt8(ascii: "t"): return [0x09]
        case UInt8(ascii: "u"):
            guard index + 4 <= bytes.count,
                let unit = UInt16(String(decoding: bytes[index..<index + 4], as: UTF8.self), radix: 16)
            else { throw fail("invalid unicode escape") }
            index += 4
            return [unit]
        default: throw fail("invalid escape")
        }
    }

    mutating func parseNumber() throws(JSONParseError) -> Double {
        let start = index
        if index < bytes.count, bytes[index] == UInt8(ascii: "-") { index += 1 }
        let digits = { (parser: inout JSONParser) -> Int in
            let from = parser.index
            while parser.index < parser.bytes.count, (0x30...0x39).contains(parser.bytes[parser.index]) { parser.index += 1 }
            return parser.index - from
        }
        let integer = index
        guard digits(&self) > 0 else { throw fail("unexpected token") }
        if bytes[integer] == 0x30, index - integer > 1 { throw fail("leading zero") }
        if index < bytes.count, bytes[index] == UInt8(ascii: ".") {
            index += 1
            guard digits(&self) > 0 else { throw fail("expected digits") }
        }
        if index < bytes.count, bytes[index] == UInt8(ascii: "e") || bytes[index] == UInt8(ascii: "E") {
            index += 1
            if index < bytes.count, bytes[index] == UInt8(ascii: "+") || bytes[index] == UInt8(ascii: "-") { index += 1 }
            guard digits(&self) > 0 else { throw fail("expected exponent digits") }
        }
        guard let value = Double(String(decoding: bytes[start..<index], as: UTF8.self)) else { throw fail("invalid number") }
        return value
    }
}

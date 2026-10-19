import Foundation

public struct JSONParseError: Error, Sendable, CustomStringConvertible {
    public let offset: Int
    public let reason: String

    public var description: String { "Invalid JSON at byte \(offset): \(reason)" }
}

extension JSONValue {
    public static let maxNestingDepth = 512

    public init(parsing text: String) throws(JSONParseError) {
        try self.init(parsing: Data(text.utf8))
    }

    public init(parsing data: Data) throws(JSONParseError) {
        var parser = JSONParser(bytes: [UInt8](data))
        self = try parser.parseDocument()
    }
}

private enum Container {
    case array([JSONValue])
    case object(JSONObject, String)
}

private struct JSONParser {
    let bytes: [UInt8]
    var index = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func parseDocument() throws(JSONParseError) -> JSONValue {
        var stack: [Container] = []
        while true {
            guard var value = try openValue(&stack) else { continue }
            while true {
                guard let top = stack.popLast() else {
                    skipWhitespace()
                    guard index == bytes.count else { throw fail("unexpected trailing content") }
                    return value
                }
                skipWhitespace()
                guard index < bytes.count else { throw fail("unexpected end of input") }
                let byte = bytes[index]
                index += 1
                switch top {
                case .array(var items):
                    items.append(value)
                    if byte == UInt8(ascii: ",") {
                        stack.append(.array(items))
                        break
                    }
                    guard byte == UInt8(ascii: "]") else { throw fail("expected ',' or ']'") }
                    value = .array(items)
                    continue
                case .object(var object, let key):
                    object[key] = value
                    if byte == UInt8(ascii: ",") {
                        stack.append(.object(object, try parseKey()))
                        break
                    }
                    guard byte == UInt8(ascii: "}") else { throw fail("expected ',' or '}'") }
                    value = .object(object)
                    continue
                }
                break
            }
        }
    }

    func fail(_ reason: String) -> JSONParseError {
        JSONParseError(offset: index, reason: reason)
    }

    mutating func skipWhitespace() {
        while index < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[index]) { index += 1 }
    }

    mutating func openValue(_ stack: inout [Container]) throws(JSONParseError) -> JSONValue? {
        skipWhitespace()
        guard index < bytes.count else { throw fail("unexpected end of input") }
        let opens = bytes[index] == UInt8(ascii: "[") || bytes[index] == UInt8(ascii: "{")
        if opens && stack.count >= JSONValue.maxNestingDepth { throw fail("nesting deeper than \(JSONValue.maxNestingDepth) levels") }
        switch bytes[index] {
        case UInt8(ascii: "["):
            index += 1
            skipWhitespace()
            if index < bytes.count, bytes[index] == UInt8(ascii: "]") {
                index += 1
                return .array([])
            }
            stack.append(.array([]))
            return nil
        case UInt8(ascii: "{"):
            index += 1
            skipWhitespace()
            if index < bytes.count, bytes[index] == UInt8(ascii: "}") {
                index += 1
                return .object(JSONObject())
            }
            stack.append(.object(JSONObject(), try parseKey()))
            return nil
        case UInt8(ascii: "\""): return .string(try parseString())
        case UInt8(ascii: "t"): return try literal("true", .bool(true))
        case UInt8(ascii: "f"): return try literal("false", .bool(false))
        case UInt8(ascii: "n"): return try literal("null", .null)
        default: return .number(try parseNumber())
        }
    }

    mutating func parseKey() throws(JSONParseError) -> String {
        skipWhitespace()
        guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else { throw fail("expected a property name") }
        let key = try parseString()
        skipWhitespace()
        guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else { throw fail("expected ':'") }
        index += 1
        return key
    }

    mutating func literal(_ word: String, _ value: JSONValue) throws(JSONParseError) -> JSONValue {
        let expected = Array(word.utf8)
        guard index + expected.count <= bytes.count, Array(bytes[index..<index + expected.count]) == expected else {
            throw fail("unexpected token")
        }
        index += expected.count
        return value
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
                let escaped = try parseEscape()
                if UTF16.isTrailSurrogate(escaped) { throw fail("lone surrogate in string") }
                units.append(escaped)
                if UTF16.isLeadSurrogate(escaped) {
                    guard index < bytes.count, bytes[index] == UInt8(ascii: "\\") else { throw fail("lone surrogate in string") }
                    let trail = try parseEscape()
                    guard UTF16.isTrailSurrogate(trail) else { throw fail("lone surrogate in string") }
                    units.append(trail)
                }
                continue
            }
            let start = index
            while index < bytes.count, bytes[index] != UInt8(ascii: "\""), bytes[index] != UInt8(ascii: "\\"), bytes[index] >= 0x20 {
                index += 1
            }
            _ = transcode(bytes[start..<index].makeIterator(), from: UTF8.self, to: UTF16.self, stoppingOnError: false) {
                units.append($0)
            }
        }
    }

    mutating func parseEscape() throws(JSONParseError) -> UInt16 {
        index += 1
        guard index < bytes.count else { throw fail("unterminated escape") }
        let byte = bytes[index]
        index += 1
        switch byte {
        case UInt8(ascii: "\""): return 0x22
        case UInt8(ascii: "\\"): return 0x5C
        case UInt8(ascii: "/"): return 0x2F
        case UInt8(ascii: "b"): return 0x08
        case UInt8(ascii: "f"): return 0x0C
        case UInt8(ascii: "n"): return 0x0A
        case UInt8(ascii: "r"): return 0x0D
        case UInt8(ascii: "t"): return 0x09
        case UInt8(ascii: "u"):
            guard index + 4 <= bytes.count, bytes[index..<index + 4].allSatisfy({ Character(Unicode.Scalar($0)).isHexDigit }),
                let hex = String(bytes: bytes[index..<index + 4], encoding: .ascii), let unit = UInt16(hex, radix: 16)
            else { throw fail("invalid unicode escape") }
            index += 4
            return unit
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
        guard let text = String(bytes: bytes[start..<index], encoding: .ascii), let value = Double(text) else {
            throw fail("invalid number")
        }
        return value
    }
}

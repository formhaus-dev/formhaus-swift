import FormhausCore
import Foundation

indirect enum RawJSON {
    case null
    case bool(Bool)
    case number(Double)
    case string([UInt16])
    case array([RawJSON])
    case object([(key: [UInt16], value: RawJSON)])

    subscript(key: String) -> RawJSON? {
        guard case .object(let members) = self else { return nil }
        return members.last { $0.key.elementsEqual(key.utf16) }?.value
    }

    var units: [UInt16]? {
        if case .string(let units) = self { return units }
        return nil
    }

    var number: Double? {
        if case .number(let number) = self { return number }
        return nil
    }

    var items: [RawJSON] {
        if case .array(let items) = self { return items }
        return []
    }

    func value(without dropped: String) -> JSONValue? {
        switch self {
        case .null: return .null
        case .bool(let flag): return .bool(flag)
        case .number(let number): return .number(number)
        case .string(let units): return text(units).map(JSONValue.string)
        case .array(let items):
            let values = items.compactMap { $0.value(without: "") }
            return values.count == items.count ? .array(values) : nil
        case .object(let members):
            var object = JSONObject()
            for member in members where !member.key.elementsEqual(dropped.utf16) {
                guard let key = text(member.key), let value = member.value.value(without: "") else { return nil }
                object[key] = value
            }
            return .object(object)
        }
    }

    private func text(_ units: [UInt16]) -> String? {
        let decoded = String(decoding: units, as: UTF16.self)
        return decoded.utf16.elementsEqual(units) ? decoded : nil
    }
}

struct RawReader {
    private let bytes: [UInt8]
    private var index = 0

    static func parse(_ data: Data) -> RawJSON? {
        var reader = RawReader(bytes: [UInt8](data))
        let value = reader.value()
        reader.skipSpace()
        return reader.index == reader.bytes.count ? value : nil
    }

    private init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    private mutating func skipSpace() {
        while index < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[index]) { index += 1 }
    }

    private mutating func take(_ byte: UInt8) -> Bool {
        skipSpace()
        guard index < bytes.count, bytes[index] == byte else { return false }
        index += 1
        return true
    }

    private mutating func value() -> RawJSON? {
        skipSpace()
        guard index < bytes.count else { return nil }
        switch bytes[index] {
        case UInt8(ascii: "{"): return members()
        case UInt8(ascii: "["): return elements()
        case UInt8(ascii: "\""): return string().map(RawJSON.string)
        case UInt8(ascii: "t"): return word("true", .bool(true))
        case UInt8(ascii: "f"): return word("false", .bool(false))
        case UInt8(ascii: "n"): return word("null", .null)
        default: return number()
        }
    }

    private mutating func members() -> RawJSON? {
        index += 1
        var members: [(key: [UInt16], value: RawJSON)] = []
        if take(UInt8(ascii: "}")) { return .object(members) }
        repeat {
            skipSpace()
            guard let key = string(), take(UInt8(ascii: ":")), let item = value() else { return nil }
            members.append((key, item))
        } while take(UInt8(ascii: ","))
        return take(UInt8(ascii: "}")) ? .object(members) : nil
    }

    private mutating func elements() -> RawJSON? {
        index += 1
        var items: [RawJSON] = []
        if take(UInt8(ascii: "]")) { return .array(items) }
        repeat {
            guard let item = value() else { return nil }
            items.append(item)
        } while take(UInt8(ascii: ","))
        return take(UInt8(ascii: "]")) ? .array(items) : nil
    }

    private mutating func word(_ text: String, _ result: RawJSON) -> RawJSON? {
        let expected = Array(text.utf8)
        guard bytes[index...].starts(with: expected) else { return nil }
        index += expected.count
        return result
    }

    private mutating func number() -> RawJSON? {
        let start = index
        while index < bytes.count, "+-.eE0123456789".utf8.contains(bytes[index]) { index += 1 }
        return String(bytes: bytes[start..<index], encoding: .ascii).flatMap(Double.init).map(RawJSON.number)
    }

    private mutating func string() -> [UInt16]? {
        guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else { return nil }
        index += 1
        var units: [UInt16] = []
        var start = index
        while index < bytes.count, bytes[index] != UInt8(ascii: "\"") {
            guard bytes[index] == UInt8(ascii: "\\") else {
                index += 1
                continue
            }
            append(&units, from: start)
            guard let unit = escape() else { return nil }
            units.append(unit)
            start = index
        }
        guard index < bytes.count else { return nil }
        append(&units, from: start)
        index += 1
        return units
    }

    private func append(_ units: inout [UInt16], from start: Int) {
        _ = transcode(bytes[start..<index].makeIterator(), from: UTF8.self, to: UTF16.self, stoppingOnError: false) { units.append($0) }
    }

    private mutating func escape() -> UInt16? {
        guard index + 1 < bytes.count else { return nil }
        let kind = bytes[index + 1]
        index += 2
        let simple: [UInt8: UInt16] = [
            UInt8(ascii: "\""): 0x22, UInt8(ascii: "\\"): 0x5C, UInt8(ascii: "/"): 0x2F, UInt8(ascii: "b"): 0x08,
            UInt8(ascii: "f"): 0x0C, UInt8(ascii: "n"): 0x0A, UInt8(ascii: "r"): 0x0D, UInt8(ascii: "t"): 0x09,
        ]
        if let unit = simple[kind] { return unit }
        guard kind == UInt8(ascii: "u"), index + 4 <= bytes.count else { return nil }
        defer { index += 4 }
        return String(bytes: bytes[index..<index + 4], encoding: .ascii).flatMap { UInt16($0, radix: 16) }
    }
}

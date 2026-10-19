import Foundation

private let jsWhitespace: Set<UInt32> = [
    0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0xA0, 0x1680, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006,
    0x2007, 0x2008, 0x2009, 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF,
]

extension String {
    var jsTrimmed: String {
        let scalars = unicodeScalars
        guard let start = scalars.firstIndex(where: { !jsWhitespace.contains($0.value) }) else { return "" }
        let end = scalars.lastIndex(where: { !jsWhitespace.contains($0.value) })!
        return String(scalars[start...end])
    }

    var jsLength: Int { utf16.count }

    var isBlankText: Bool { jsTrimmed.isEmpty }
}

func codeUnitLess(_ lhs: String, _ rhs: String) -> Bool {
    lhs.utf16.lexicographicallyPrecedes(rhs.utf16)
}

func codeUnitCompare(_ lhs: String, _ rhs: String) -> Int {
    if lhs.utf16.elementsEqual(rhs.utf16) { return 0 }
    return codeUnitLess(lhs, rhs) ? -1 : 1
}

func jsNumberString(_ value: Double) -> String {
    if value.isNaN { return "NaN" }
    if value.isInfinite { return value < 0 ? "-Infinity" : "Infinity" }
    if value == 0 { return "0" }
    let sign = value < 0 ? "-" : ""
    let (digits, exponent) = shortestDigits(abs(value))
    let count = digits.count
    if exponent >= count && exponent <= 21 {
        return sign + digits + String(repeating: "0", count: exponent - count)
    }
    if exponent > 0 && exponent <= 21 {
        let split = digits.index(digits.startIndex, offsetBy: exponent)
        return sign + digits[..<split] + "." + digits[split...]
    }
    if exponent > -6 && exponent <= 0 {
        return sign + "0." + String(repeating: "0", count: -exponent) + digits
    }
    let power = exponent - 1
    let mantissa = count == 1 ? digits : String(digits.prefix(1)) + "." + digits.dropFirst()
    return sign + mantissa + "e" + (power < 0 ? "-" : "+") + String(abs(power))
}

private func shortestDigits(_ value: Double) -> (String, Int) {
    let text = "\(value)"
    let parts = text.split(separator: "e", maxSplits: 1)
    let mantissa = String(parts[0])
    var exponent = parts.count > 1 ? Int(parts[1])! : 0
    let pieces = mantissa.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    let whole = String(pieces[0])
    var fraction = pieces.count > 1 ? String(pieces[1]) : ""
    if fraction == "0" { fraction = "" }
    var digits = whole + fraction
    exponent += whole.count
    while digits.hasPrefix("0") {
        digits.removeFirst()
        exponent -= 1
    }
    while digits.hasSuffix("0") { digits.removeLast() }
    return (digits, exponent)
}

func jsNumber(fromString text: String) -> Double {
    let trimmed = text.jsTrimmed
    if trimmed.isEmpty { return 0 }
    switch trimmed {
    case "Infinity", "+Infinity": return .infinity
    case "-Infinity": return -.infinity
    default: break
    }
    let lower = trimmed.lowercased()
    for (prefix, radix) in [("0x", 16), ("0o", 8), ("0b", 2)] where lower.hasPrefix(prefix) {
        let body = trimmed.dropFirst(2)
        guard !body.isEmpty, body.allSatisfy({ $0.isASCII && $0.hexDigitValue.map { $0 < radix } == true }) else { return .nan }
        return body.reduce(0.0) { $0 * Double(radix) + Double($1.hexDigitValue!) }
    }
    guard isDecimalLiteral(trimmed), let number = Double(trimmed) else { return .nan }
    return number
}

private func isDecimalLiteral(_ text: String) -> Bool {
    var chars = Array(text.utf8)
    if let first = chars.first, first == UInt8(ascii: "+") || first == UInt8(ascii: "-") { chars.removeFirst() }
    var index = 0
    let isDigit = { (byte: UInt8) in (0x30...0x39).contains(byte) }
    var whole = 0
    while index < chars.count, isDigit(chars[index]) {
        index += 1
        whole += 1
    }
    var fraction = 0
    if index < chars.count, chars[index] == UInt8(ascii: ".") {
        index += 1
        while index < chars.count, isDigit(chars[index]) {
            index += 1
            fraction += 1
        }
    }
    guard whole + fraction > 0 else { return false }
    if index < chars.count, chars[index] == UInt8(ascii: "e") || chars[index] == UInt8(ascii: "E") {
        index += 1
        if index < chars.count, chars[index] == UInt8(ascii: "+") || chars[index] == UInt8(ascii: "-") { index += 1 }
        var power = 0
        while index < chars.count, isDigit(chars[index]) {
            index += 1
            power += 1
        }
        guard power > 0 else { return false }
    }
    return index == chars.count
}

private enum Piece {
    case text(String)
    case value(JSONValue)
}

private func scalarString(_ value: JSONValue) -> String {
    switch value {
    case .null: "null"
    case .bool(let flag): flag ? "true" : "false"
    case .number(let number): jsNumberString(number)
    case .string(let text): text
    case .array, .object: "[object Object]"
    }
}

func jsString(_ value: JSONValue?) -> String {
    guard let value else { return "undefined" }
    guard case .array = value else { return scalarString(value) }
    var output = ""
    var pending: [Piece] = [.value(value)]
    while let piece = pending.popLast() {
        switch piece {
        case .text(let text): output += text
        case .value(.null): continue
        case .value(.array(let items)):
            for (index, item) in items.enumerated().reversed() {
                pending.append(.value(item))
                if index > 0 { pending.append(.text(",")) }
            }
        case .value(let item): output += scalarString(item)
        }
    }
    return output
}

func jsonStringify(_ value: JSONValue?) -> String {
    guard let value else { return "undefined" }
    var output = ""
    var pending: [Piece] = [.value(value)]
    while let piece = pending.popLast() {
        switch piece {
        case .text(let text): output += text
        case .value(.number(let number)): output += number.isFinite ? jsNumberString(number) : "null"
        case .value(.string(let text)): output += quoteJSON(text)
        case .value(.array(let items)):
            output += "["
            pending.append(.text("]"))
            for (index, item) in items.enumerated().reversed() {
                pending.append(.value(item))
                if index > 0 { pending.append(.text(",")) }
            }
        case .value(.object(let object)):
            output += "{"
            pending.append(.text("}"))
            for (index, entry) in Array(object).enumerated().reversed() {
                pending.append(.value(entry.value))
                pending.append(.text(quoteJSON(entry.key) + ":"))
                if index > 0 { pending.append(.text(",")) }
            }
        case .value(let item): output += scalarString(item)
        }
    }
    return output
}

func quoteJSON(_ text: String) -> String {
    var result = "\""
    for unit in text.unicodeScalars {
        switch unit {
        case "\"": result += "\\\""
        case "\\": result += "\\\\"
        case "\n": result += "\\n"
        case "\r": result += "\\r"
        case "\t": result += "\\t"
        case "\u{08}": result += "\\b"
        case "\u{0C}": result += "\\f"
        default:
            if unit.value < 0x20 {
                result += String(format: "\\u%04x", unit.value)
            } else {
                result.unicodeScalars.append(unit)
            }
        }
    }
    return result + "\""
}

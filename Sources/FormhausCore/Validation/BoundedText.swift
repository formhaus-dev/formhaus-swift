func cut(_ text: String) -> String {
    guard text.utf8.count > maxStringLength else { return text }
    let units = text.utf16
    guard units.count > maxStringLength else { return text }
    var end = units.index(units.startIndex, offsetBy: maxStringLength)
    let last = units.index(before: end)
    if UTF16.isLeadSurrogate(units[last]) { end = last }
    return String(text[..<end])
}

enum TemplateToken {
    case escape
    case param(String)
    case recall(String?)
}

private let backslash: UInt8 = 0x5C
private let open: UInt8 = 0x7B
private let close: UInt8 = 0x7D

private func isWordByte(_ byte: UInt8) -> Bool {
    (0x30...0x39).contains(byte) || (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte) || byte == 0x5F
}

private func isKeyScalar(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.properties.generalCategory {
    case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter, .nonspacingMark, .spacingMark,
        .enclosingMark, .decimalNumber, .letterNumber, .otherNumber:
        true
    default: scalar == "_" || scalar == "." || scalar == "-"
    }
}

func recallKey(_ content: Substring) -> String? {
    let key = String(content).jsTrimmed
    return !key.isEmpty && key.unicodeScalars.allSatisfy(isKeyScalar) ? key : nil
}

func hasRecallBraces(_ text: String) -> Bool {
    var previous: UInt8 = 0
    return text.utf8.contains { byte in
        defer { previous = byte }
        return byte == open && previous == open
    }
}

private func tokenEnd(_ text: String, _ start: String.Index) -> (end: String.Index, token: TemplateToken)? {
    let bytes = text.utf8
    let next = bytes.index(after: start)
    if bytes[start] == backslash {
        return bytes[next...].starts(with: [open, open]) ? (bytes.index(next, offsetBy: 2), .escape) : nil
    }
    if next < bytes.endIndex, bytes[next] == open {
        let body = bytes.index(after: next)
        let stop = bytes[body...].firstIndex { $0 == open || $0 == close } ?? bytes.endIndex
        if bytes[stop...].starts(with: [close, close]) { return (bytes.index(stop, offsetBy: 2), .recall(recallKey(text[body..<stop]))) }
    }
    let stop = bytes[next...].firstIndex { !isWordByte($0) } ?? bytes.endIndex
    guard stop > next, stop < bytes.endIndex, bytes[stop] == close else { return nil }
    return (bytes.index(after: stop), .param(String(text[next..<stop])))
}

func forEachToken(_ text: String, _ body: (Range<String.Index>, TemplateToken) -> Bool) {
    let bytes = text.utf8
    var index = bytes.startIndex
    while let start = bytes[index...].firstIndex(where: { $0 == open || $0 == backslash }) {
        guard let (end, token) = tokenEnd(text, start) else {
            index = bytes.index(after: start)
            continue
        }
        guard body(start..<end, token) else { return }
        index = end
    }
}

func fillTemplate(_ text: String, _ replace: (Substring, TemplateToken) -> String) -> String {
    var result = ""
    var units = 0
    var last = text.startIndex
    forEachToken(text) { range, token in
        guard units <= maxStringLength else { return false }
        let head = text[last..<range.lowerBound]
        let value = replace(text[range], token)
        result += head
        result += value
        units += head.utf16.count + value.utf16.count
        last = range.upperBound
        return true
    }
    result += text[last...]
    return cut(result)
}

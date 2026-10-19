struct CaptureScan {
    let names: [String?]

    init(_ units: [UInt16]) {
        var names: [String?] = []
        var index = 0
        var inClass = false
        while index < units.count {
            let unit = units[index]
            if unit == UInt16(ascii: "\\") {
                index += 2
                continue
            }
            if inClass {
                inClass = unit != UInt16(ascii: "]")
            } else if unit == UInt16(ascii: "[") {
                inClass = true
            } else if unit == UInt16(ascii: "(") {
                if let name = Self.groupStart(units, index + 1) { names.append(name) }
            }
            index += 1
        }
        self.names = names
    }

    var hasNames: Bool { names.contains { $0 != nil } }

    func indices(of name: String) -> [Int] {
        names.indices.filter { names[$0] == name }.map { $0 + 1 }
    }

    private static func groupStart(_ units: [UInt16], _ index: Int) -> String?? {
        guard index < units.count, units[index] == UInt16(ascii: "?") else { return .some(nil) }
        guard index + 2 < units.count, units[index + 1] == UInt16(ascii: "<"),
            units[index + 2] != UInt16(ascii: "="), units[index + 2] != UInt16(ascii: "!")
        else { return nil }
        return .some(parseGroupName(units, from: index + 2)?.name ?? "")
    }
}

struct GroupName {
    let name: String
    let end: Int
}

func parseGroupName(_ units: [UInt16], from start: Int) -> GroupName? {
    var index = start
    var scalars = String.UnicodeScalarView()
    while index < units.count {
        if units[index] == UInt16(ascii: ">") {
            return scalars.isEmpty ? nil : GroupName(name: String(scalars), end: index + 1)
        }
        guard let (scalar, next) = nameScalar(units, index), isNameScalar(scalar, start: scalars.isEmpty) else { return nil }
        scalars.append(scalar)
        index = next
    }
    return nil
}

func hexValue(_ units: [UInt16], at index: Int, count: Int) -> Int? {
    guard index + count <= units.count else { return nil }
    var value = 0
    for unit in units[index..<index + count] {
        guard let digit = hexDigit(unit) else { return nil }
        value = value * 16 + digit
    }
    return value
}

private func hexDigit(_ unit: UInt16) -> Int? {
    switch unit {
    case 0x30...0x39: Int(unit) - 0x30
    case 0x41...0x46: Int(unit) - 0x37
    case 0x61...0x66: Int(unit) - 0x57
    default: nil
    }
}

private func isNameScalar(_ scalar: Unicode.Scalar, start: Bool) -> Bool {
    if scalar == "$" || scalar == "_" { return true }
    if start { return scalar.properties.isIDStart }
    return scalar == "\u{200C}" || scalar == "\u{200D}" || scalar.properties.isIDContinue
}

private func isLead(_ unit: Int) -> Bool { (0xD800...0xDBFF).contains(unit) }

private func isTrail(_ unit: Int) -> Bool { (0xDC00...0xDFFF).contains(unit) }

private func combine(_ lead: Int, _ trail: Int) -> Unicode.Scalar? {
    Unicode.Scalar(UInt32(0x10000 + (lead - 0xD800) << 10 + (trail - 0xDC00)))
}

private func nameScalar(_ units: [UInt16], _ index: Int) -> (Unicode.Scalar, Int)? {
    let unit = Int(units[index])
    if unit == Int(UInt16(ascii: "\\")) { return escapedScalar(units, index + 1) }
    if isLead(unit), index + 1 < units.count, isTrail(Int(units[index + 1])) {
        return combine(unit, Int(units[index + 1])).map { ($0, index + 2) }
    }
    return Unicode.Scalar(UInt32(unit)).map { ($0, index + 1) }
}

private func escapedScalar(_ units: [UInt16], _ index: Int) -> (Unicode.Scalar, Int)? {
    guard index < units.count, units[index] == UInt16(ascii: "u") else { return nil }
    if index + 1 < units.count, units[index + 1] == UInt16(ascii: "{") { return bracedScalar(units, index + 2) }
    guard let lead = hexValue(units, at: index + 1, count: 4) else { return nil }
    let rest = index + 5
    if isLead(lead), rest + 1 < units.count, units[rest] == UInt16(ascii: "\\"), units[rest + 1] == UInt16(ascii: "u"),
        let trail = hexValue(units, at: rest + 2, count: 4), isTrail(trail)
    {
        return combine(lead, trail).map { ($0, rest + 6) }
    }
    return Unicode.Scalar(UInt32(lead)).map { ($0, rest) }
}

private func bracedScalar(_ units: [UInt16], _ start: Int) -> (Unicode.Scalar, Int)? {
    var index = start
    var value = 0
    while index < units.count, let digit = hexValue(units, at: index, count: 1) {
        value = min(value * 16 + digit, 0x110000)
        index += 1
    }
    guard index > start, index < units.count, units[index] == UInt16(ascii: "}") else { return nil }
    return Unicode.Scalar(UInt32(value)).map { ($0, index + 1) }
}

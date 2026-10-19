extension RegexParser {
    mutating func parseAtomEscape() throws(RegexSyntaxError) -> Atom {
        guard let unit = peek() else { throw RegexSyntaxError() }
        switch scalar(unit) {
        case "b", "B":
            index += 1
            return Atom(node: .assertion(unit == UInt16(ascii: "b") ? .wordBoundary : .notWordBoundary), quantifiable: false)
        case "1"..."9":
            if let reference = decimalReference() { return Atom(node: reference, quantifiable: true) }
        case "k":
            if groups.hasNames { return Atom(node: try namedReference(), quantifiable: true) }
        case "c":
            if !controlFollows(inClass: false) { return literal(UInt16(ascii: "\\")) }
        default:
            if let set = classEscape(unit) {
                index += 1
                return setAtom(set)
            }
        }
        return literal(try parseCharacterEscape())
    }

    func classEscape(_ unit: UInt16) -> CharSet? {
        switch scalar(unit) {
        case "d": .digit
        case "D": .notDigit
        case "s": .space
        case "S": .notSpace
        case "w": .word
        case "W": .notWord
        default: nil
        }
    }

    func controlFollows(inClass: Bool) -> Bool {
        guard let next = peek(1) else { return false }
        let letter = (0x41...0x5A).contains(next) || (0x61...0x7A).contains(next)
        return letter || inClass && (decimalDigit(next) != nil || next == UInt16(ascii: "_"))
    }

    mutating func parseCharacterEscape() throws(RegexSyntaxError) -> UInt16 {
        let unit = units[index]
        index += 1
        switch scalar(unit) {
        case "f": return 0x0C
        case "n": return 0x0A
        case "r": return 0x0D
        case "t": return 0x09
        case "v": return 0x0B
        case "c":
            index += 1
            return units[index - 1] % 32
        case "0"..."7": return legacyOctal(unit)
        case "x": return hexEscape(count: 2) ?? unit
        case "u": return hexEscape(count: 4) ?? unit
        case "k":
            guard !groups.hasNames else { throw RegexSyntaxError() }
            return unit
        default: return unit
        }
    }

    private mutating func hexEscape(count: Int) -> UInt16? {
        guard let value = hexValue(units, at: index, count: count) else { return nil }
        index += count
        return UInt16(value)
    }

    private mutating func legacyOctal(_ first: UInt16) -> UInt16 {
        var value = Int(first) - 0x30
        guard let second = octalDigit() else { return UInt16(value) }
        value = value * 8 + second
        if first <= UInt16(ascii: "3"), let third = octalDigit() { value = value * 8 + third }
        return UInt16(value)
    }

    private mutating func octalDigit() -> Int? {
        guard let unit = peek(), (0x30...0x37).contains(unit) else { return nil }
        index += 1
        return Int(unit) - 0x30
    }

    private mutating func decimalReference() -> RegexNode? {
        var cursor = index
        var value = 0
        while cursor < units.count, let digit = decimalDigit(units[cursor]) {
            value = min(value * 10 + digit, Int(Int32.max))
            cursor += 1
        }
        guard value <= groups.names.count else { return nil }
        index = cursor
        return .backreference([value], ignoreCase: modifiers.ignoreCase)
    }

    private mutating func namedReference() throws(RegexSyntaxError) -> RegexNode {
        index += 1
        guard consume("<"), let name = parseGroupName(units, from: index) else { throw RegexSyntaxError() }
        index = name.end
        let indices = groups.indices(of: name.name)
        guard !indices.isEmpty else { throw RegexSyntaxError() }
        return .backreference(indices, ignoreCase: modifiers.ignoreCase)
    }

    mutating func parseClass() throws(RegexSyntaxError) -> RegexNode {
        let negated = consume("^")
        var ranges: [ClosedRange<UInt16>] = []
        while !consume("]") {
            guard peek() != nil else { throw RegexSyntaxError() }
            let first = try parseClassAtom()
            guard at("-"), let next = peek(1), next != UInt16(ascii: "]") else {
                ranges += first.ranges
                continue
            }
            index += 1
            let second = try parseClassAtom()
            if let lower = first.single, let upper = second.single {
                guard lower <= upper else { throw RegexSyntaxError() }
                ranges.append(lower...upper)
            } else {
                ranges += first.ranges + ClassAtom.unit(UInt16(ascii: "-")).ranges + second.ranges
            }
        }
        let members = CharSet(ranges)
        let folded = modifiers.ignoreCase ? CaseFolding.fold(members) : members
        return .set(negated ? folded.inverted : folded)
    }

    private mutating func parseClassAtom() throws(RegexSyntaxError) -> ClassAtom {
        let unit = units[index]
        index += 1
        guard unit == UInt16(ascii: "\\") else { return .unit(unit) }
        guard let next = peek() else { throw RegexSyntaxError() }
        if next == UInt16(ascii: "b") {
            index += 1
            return .unit(0x08)
        }
        if next == UInt16(ascii: "c"), !controlFollows(inClass: true) { return .unit(unit) }
        if let set = classEscape(next) {
            index += 1
            return .set(set)
        }
        return .unit(try parseCharacterEscape())
    }
}

enum ClassAtom {
    case unit(UInt16)
    case set(CharSet)

    var single: UInt16? {
        guard case .unit(let unit) = self else { return nil }
        return unit
    }

    var ranges: [ClosedRange<UInt16>] {
        switch self {
        case .unit(let unit): [unit...unit]
        case .set(let set): set.ranges
        }
    }
}

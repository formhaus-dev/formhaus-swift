enum TokenKind {
    case open(look: Bool)
    case atom(end: Int)
    case other
}

struct PatternQuantifier {
    var end: Int
    var present = false
    var repeats = false
    var unbounded = false
    var optional = false
}

struct PatternLexer {
    let units: [UInt16]
    private let classEnds: [Int?]

    init(_ units: [UInt16]) {
        self.units = units
        var ends = [Int?](repeating: nil, count: units.count + 2)
        for index in units.indices.reversed() {
            switch units[index] {
            case code("]"): ends[index] = index + 1
            case code("\\"): ends[index] = ends[index + 2] ?? ends[index + 1]
            default: ends[index] = ends[index + 1]
            }
        }
        classEnds = ends
    }

    func unit(_ index: Int) -> UInt16? {
        index < units.count ? units[index] : nil
    }

    func token(at index: Int) -> (kind: TokenKind, end: Int) {
        let char = units[index]
        if char == code("(") { return open(at: index) }
        if let end = atomEnd(at: index) { return (.atom(end: end), end) }
        return (.other, char == code("\\") && index + 1 < units.count ? index + 2 : index + 1)
    }

    private func open(at index: Int) -> (kind: TokenKind, end: Int) {
        guard unit(index + 1) == code("?") else { return (.open(look: false), index + 1) }
        let next = index + 2
        if let char = unit(next), lookMarks.contains(char) { return (.open(look: true), next + 1) }
        if unit(next) == code("<"), let char = unit(next + 1), lookMarks.contains(char) { return (.open(look: true), next + 2) }
        if unit(next) == code(":") { return (.open(look: false), next + 1) }
        if unit(next) == code("<"), let close = units[(next + 1)...].firstIndex(of: code(">")) { return (.open(look: false), close + 1) }
        return (.open(look: false), index + 1)
    }

    private func atomEnd(at index: Int) -> Int? {
        switch units[index] {
        case code(")"): index + 1
        case code("\\"): escapeEnd(at: index)
        case code("["): classEnds[index + 1] ?? index + 1
        case code("|"), code("^"), code("$"): nil
        default: index + 1
        }
    }

    private func escapeEnd(at index: Int) -> Int? {
        guard let char = unit(index + 1) else { return nil }
        let lower = char | 0x20
        if lower == code("x"), hex(from: index + 2, count: 2) { return index + 4 }
        if lower == code("u"), hex(from: index + 2, count: 4) { return index + 6 }
        if lower == code("c"), let letter = unit(index + 2), (code("a")...code("z")).contains(letter | 0x20) { return index + 3 }
        if isDigit(char) { return digitsEnd(from: index + 1) }
        if lower == code("k"), let end = groupNameEnd(from: index + 2) { return end }
        return lower == code("b") ? nil : index + 2
    }

    private func groupNameEnd(from start: Int) -> Int? {
        guard unit(start) == code("<") else { return nil }
        var index = start + 1
        while let end = nameUnitEnd(at: index) { index = end }
        return index > start + 1 && unit(index) == code(">") ? index + 1 : nil
    }

    private func nameUnitEnd(at index: Int) -> Int? {
        guard let char = unit(index) else { return nil }
        if char == code("$") || char >= 0x80 || isWordUnit(char) { return index + 1 }
        guard char == code("\\"), let next = unit(index + 1), next | 0x20 == code("u") else { return nil }
        if hex(from: index + 2, count: 4) { return index + 6 }
        guard unit(index + 2) == code("{") else { return nil }
        let close = hexEnd(from: index + 3)
        return close > index + 3 && unit(close) == code("}") ? close + 1 : nil
    }

    private func isHex(_ index: Int) -> Bool {
        unit(index).map { isDigit($0) || (code("a")...code("f")).contains($0 | 0x20) } ?? false
    }

    private func hex(from start: Int, count: Int) -> Bool {
        (start..<start + count).allSatisfy(isHex)
    }

    private func hexEnd(from start: Int) -> Int {
        var index = start
        while isHex(index) { index += 1 }
        return index
    }

    private func digitsEnd(from start: Int) -> Int {
        var index = start
        while let char = unit(index), isDigit(char) { index += 1 }
        return index
    }

    func quantifier(at start: Int) -> PatternQuantifier {
        var result = PatternQuantifier(end: start)
        guard let char = unit(start) else { return result }
        if [code("*"), code("+"), code("?")].contains(char) {
            result = PatternQuantifier(
                end: start + 1, present: true, repeats: char != code("?"), unbounded: char != code("?"), optional: char != code("+"))
        } else if char == code("{"), let braced = braced(at: start) {
            result = braced
        } else {
            return result
        }
        if unit(result.end) == code("?") { result.end += 1 }
        return result
    }

    private func braced(at start: Int) -> PatternQuantifier? {
        let minimumEnd = digitsEnd(from: start + 1)
        guard minimumEnd > start + 1 else { return nil }
        var index = minimumEnd
        var open = false
        if unit(index) == code(",") {
            index = digitsEnd(from: index + 1)
            open = index == minimumEnd + 1
        }
        guard unit(index) == code("}") else { return nil }
        let zero = minimumEnd == start + 2 && unit(start + 1) == code("0")
        return PatternQuantifier(end: index + 1, present: true, repeats: true, unbounded: open, optional: zero)
    }
}

private let lookMarks: Set<UInt16> = [code("="), code("!")]

func code(_ scalar: Unicode.Scalar) -> UInt16 {
    UInt16(scalar.value)
}

func isDigit(_ char: UInt16) -> Bool {
    (code("0")...code("9")).contains(char)
}

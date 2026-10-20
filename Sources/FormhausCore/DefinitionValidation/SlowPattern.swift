enum SlowPattern {
    case nested
    case adjacent
}

private struct PatternGroup {
    var start: Int
    var look = false
    var inner = false
    var alternated = false
    var entry: Set<UInt16>?
    var previous: Set<UInt16>?
}

extension PatternGroup {
    mutating func separate(alternation: Bool) {
        inner = inner || alternation
        alternated = alternated || alternation
        previous = alternation ? entry : nil
    }
}

private enum TokenKind {
    case open(look: Bool)
    case atom(end: Int)
    case other
}

private struct PatternQuantifier {
    var end: Int
    var present = false
    var repeats = false
    var unbounded = false
    var optional = false
}

private struct PatternLexer {
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
        return lower == code("b") ? nil : index + 2
    }

    private func hex(from start: Int, count: Int) -> Bool {
        (start..<start + count).allSatisfy { index in
            unit(index).map { isDigit($0) || (code("a")...code("f")).contains($0 | 0x20) } ?? false
        }
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

private func code(_ scalar: Unicode.Scalar) -> UInt16 {
    UInt16(scalar.value)
}

private func isDigit(_ char: UInt16) -> Bool {
    (code("0")...code("9")).contains(char)
}

private func samples(_ atom: ArraySlice<UInt16>) -> Set<UInt16> {
    let source = "^(?:" + String(decoding: atom, as: UTF16.self) + ")$"
    guard let pattern = try? CompiledPattern(source) else { return [] }
    return Set((0..<128).filter { pattern.test(String(UnicodeScalar(UInt8($0)))) == true }.map(UInt16.init))
}

private enum Trailing {
    case adjacent
    case previous(Set<UInt16>?)
}

private func trailing(_ group: PatternGroup, _ quantifier: PatternQuantifier, _ source: ArraySlice<UInt16>) -> Trailing {
    guard quantifier.unbounded else { return .previous(quantifier.optional ? group.previous : nil) }
    let repeated = samples(source)
    if let previous = group.previous, !previous.isDisjoint(with: repeated) { return .adjacent }
    return .previous(quantifier.optional ? repeated.union(group.previous ?? []) : repeated)
}

private enum Closing {
    case invalid
    case nested
    case settled
    case repeated(Range<Int>)
}

private func close(_ groups: inout [PatternGroup], _ quantifier: PatternQuantifier, _ end: Int) -> Closing {
    guard groups.count >= 2 else { return .invalid }
    let closed = groups.removeLast()
    let parent = groups.count - 1
    if closed.inner && quantifier.repeats { return .nested }
    groups[parent].inner = groups[parent].inner || closed.inner
    guard !closed.look && quantifier.present else {
        groups[parent].previous = closed.look || closed.alternated ? nil : closed.previous
        return .settled
    }
    return .repeated(closed.start..<end)
}

func slowPattern(_ pattern: String) -> SlowPattern? {
    let lexer = PatternLexer(Array(pattern.utf16))
    let units = lexer.units
    guard units.count <= 1000 else { return nil }
    var groups = [PatternGroup(start: 0)]
    var index = 0
    while index < units.count {
        let (kind, end) = lexer.token(at: index)
        let start = index
        index = end
        let top = groups.count - 1
        switch kind {
        case .open(let look):
            let entry = look ? nil : groups[top].previous
            groups.append(PatternGroup(start: start, look: look, entry: entry, previous: entry))
        case .other:
            groups[top].separate(alternation: units[start] == code("|"))
        case .atom(let atomEnd):
            let quantifier = lexer.quantifier(at: atomEnd)
            index = quantifier.end
            var source = start..<atomEnd
            if units[start] == code(")") {
                switch close(&groups, quantifier, atomEnd) {
                case .invalid: return nil
                case .nested: return .nested
                case .settled: continue
                case .repeated(let range): source = range
                }
            }
            let current = groups.count - 1
            groups[current].inner = groups[current].inner || quantifier.present
            switch trailing(groups[current], quantifier, units[source]) {
            case .adjacent: return .adjacent
            case .previous(let next): groups[current].previous = next
            }
        }
    }
    return nil
}

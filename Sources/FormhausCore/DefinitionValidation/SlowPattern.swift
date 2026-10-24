enum SlowPattern {
    case nested
    case adjacent
    case long
}

let slowPatternLengthLimit = 1000

private struct PatternGroup {
    var look = false
    var inner = false
    var alternated = false
    var entry = AsciiSet()
    var previous = AsciiSet()
    var chars = AsciiCounts()
    var hasLead = false
    var lead: UInt16?
    var tail: UInt16?

    var separated: UInt16? {
        guard !alternated else { return nil }
        return [lead, tail].lazy.compactMap(\.self).first(where: chars.appearsOnce)
    }

    mutating func separate(alternation: Bool) {
        inner = inner || alternation
        alternated = alternated || alternation
        previous = alternation ? entry : AsciiSet()
    }

    mutating func append(_ added: AsciiCounts, separator: UInt16?) {
        chars.add(added)
        if !hasLead { (hasLead, lead) = (true, separator) }
        tail = separator
    }
}

private struct Repeated {
    let own: AsciiCounts
    let first: AsciiSet
    let last: AsciiSet

    init(own: AsciiCounts, first: AsciiSet, last: AsciiSet) {
        self.own = own
        self.first = first
        self.last = last
    }

    init(_ set: AsciiSet) {
        var counts = AsciiCounts()
        counts.add(set)
        self.init(own: counts, first: set, last: set)
    }
}

private struct Sampler {
    private var cache: [ArraySlice<UInt16>: AsciiSet] = [:]

    mutating func samples(_ atom: ArraySlice<UInt16>) -> AsciiSet {
        if let cached = cache[atom] { return cached }
        let result = sample(atom)
        cache[atom] = result
        return result
    }

    private func sample(_ atom: ArraySlice<UInt16>) -> AsciiSet {
        if atom.count > 1, atom.first == code("\\") {
            let next = atom[atom.startIndex + 1]
            if next == code("k") || (code("1")...code("9")).contains(next) { return .all }
        }
        return asciiMatches("^(?:" + String(decoding: atom, as: UTF16.self) + ")$")
    }
}

private func isSeparatorAtom(_ atom: ArraySlice<UInt16>) -> Bool {
    switch atom.count {
    case 1: !isWordUnit(atom[atom.startIndex])
    case 2: atom.first == code("\\") && !isWordUnit(atom[atom.startIndex + 1])
    default: false
    }
}

private enum Trailing {
    case adjacent
    case previous(AsciiSet)
}

private func trailing(_ previous: AsciiSet, _ quantifier: PatternQuantifier, _ repeated: Repeated) -> Trailing {
    guard quantifier.unbounded else { return .previous(quantifier.optional ? previous : AsciiSet()) }
    if previous.intersects(repeated.first) { return .adjacent }
    return .previous(quantifier.optional ? previous.union(repeated.last) : repeated.last)
}

private enum Closing {
    case invalid
    case nested
    case closed(PatternGroup, Repeated)
}

private func close(_ groups: inout [PatternGroup], _ quantifier: PatternQuantifier) -> Closing {
    guard groups.count >= 2 else { return .invalid }
    let closed = groups.removeLast()
    let separated = closed.separated
    if closed.inner && separated == nil && quantifier.repeats { return .nested }
    let all = closed.chars.once
    let first = separated.map { $0 == closed.lead ? AsciiSet($0) : all } ?? all
    let last = separated.map { $0 == closed.tail ? AsciiSet($0) : all } ?? all
    groups[groups.count - 1].inner = groups[groups.count - 1].inner || closed.inner
    return .closed(closed, Repeated(own: closed.chars, first: first, last: last))
}

private enum ScanStep {
    case next
    case done(SlowPattern?)
}

private struct SlowPatternScan {
    private var sampler = Sampler()
    private var groups = [PatternGroup()]

    mutating func open(look: Bool) {
        let entry = look ? AsciiSet() : groups[groups.count - 1].previous
        groups.append(PatternGroup(look: look, entry: entry, previous: entry))
    }

    mutating func separate(alternation: Bool) {
        groups[groups.count - 1].separate(alternation: alternation)
    }

    mutating func atom(_ atom: ArraySlice<UInt16>, _ quantifier: PatternQuantifier) -> ScanStep {
        let parts: (repeated: Repeated, closed: PatternGroup?, separator: UInt16?)
        if atom.first == code(")") {
            switch close(&groups, quantifier) {
            case .invalid: return .done(nil)
            case .nested: return .done(.nested)
            case .closed(let group, let repeated): parts = (repeated, group, nil)
            }
        } else {
            let own = sampler.samples(atom)
            parts = (Repeated(own), nil, !quantifier.present && isSeparatorAtom(atom) ? own.single : nil)
        }
        let current = groups.count - 1
        groups[current].append(parts.repeated.own, separator: parts.separator)
        if let closed = parts.closed, closed.look || !quantifier.present {
            groups[current].previous = closed.look || closed.alternated ? AsciiSet() : closed.previous
            return .next
        }
        groups[current].inner = groups[current].inner || quantifier.present
        switch trailing(groups[current].previous, quantifier, parts.repeated) {
        case .adjacent:
            return .done(.adjacent)
        case .previous(let next):
            groups[current].previous = next
            return .next
        }
    }
}

func slowPattern(_ pattern: String) -> SlowPattern? {
    let lexer = PatternLexer(Array(pattern.utf16))
    let units = lexer.units
    guard units.count <= slowPatternLengthLimit else { return .long }
    var scan = SlowPatternScan()
    var index = 0
    while index < units.count {
        let (kind, end) = lexer.token(at: index)
        switch kind {
        case .open(let look):
            scan.open(look: look)
            index = end
        case .other:
            scan.separate(alternation: units[index] == code("|"))
            index = end
        case .atom(let atomEnd):
            let quantifier = lexer.quantifier(at: atomEnd)
            if case .done(let result) = scan.atom(units[index..<atomEnd], quantifier) { return result }
            index = quantifier.end
        }
    }
    return nil
}

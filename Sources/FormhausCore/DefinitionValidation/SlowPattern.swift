enum SlowPattern {
    case nested
    case adjacent
    case long
}

private let maxBoundedRepeat = 10.0

private struct Part {
    let chars: PatternChars
    let quantifier: PatternQuantifier
    let atom: Bool
}

private struct PatternGroup {
    var look = false
    var inner = false
    var unbounded = false
    var alternated = false
    var entry: PatternChars = []
    var previous: PatternChars = []
    var chars: PatternChars = []
    var parts: [Part] = []

    func separator(at index: Int) -> Part? {
        guard parts.indices.contains(index) else { return nil }
        let part = parts[index]
        var others = parts
        others.remove(at: index)
        guard part.atom, part.quantifier.mandatory, !overlaps(part.chars, others.flatMap(\.chars)) else { return nil }
        return part.quantifier.exact || others.contains(where: \.quantifier.mandatory) ? part : nil
    }

    var separators: (lead: PatternChars?, tail: PatternChars?) {
        guard !alternated else { return (nil, nil) }
        let lead = separator(at: 0)
        let tail = separator(at: parts.count - 1)
        if let lead, lead.quantifier.exact || tail?.quantifier.exact != true { return (lead.chars, nil) }
        return (nil, tail?.chars)
    }

    func repeats(_ quantifier: PatternQuantifier) -> Bool {
        guard inner, quantifier.repeats, !quantifier.exact else { return false }
        return quantifier.unbounded || unbounded || quantifier.bound > maxBoundedRepeat
    }
}

private enum Trailing {
    case adjacent
    case previous(PatternChars)
}

private func trailing(_ previous: PatternChars, _ quantifier: PatternQuantifier, first: PatternChars, last: PatternChars) -> Trailing {
    if quantifier.keepsPrevious { return .previous(previous) }
    guard quantifier.unbounded else { return .previous([]) }
    if overlaps(previous, first) { return .adjacent }
    return .previous(quantifier.addsToPrevious ? previous + last : last)
}

private enum ScanStep {
    case next
    case done(SlowPattern?)
}

private struct SlowPatternScan {
    private var groups = [PatternGroup()]

    mutating func open(look: Bool) {
        let entry = look ? [] : groups[groups.count - 1].previous
        groups.append(PatternGroup(look: look, entry: entry, previous: entry))
    }

    mutating func separate(alternation: Bool) {
        let current = groups.count - 1
        if alternation { (groups[current].inner, groups[current].alternated) = (true, true) }
        groups[current].previous = alternation ? groups[current].entry : []
    }

    mutating func atom(_ atom: ArraySlice<UInt16>, _ quantifier: PatternQuantifier) -> ScanStep {
        let closed = atom.first == code(")") ? groups.removeLast() : nil
        guard !groups.isEmpty else { return .done(nil) }
        let current = groups.count - 1
        let chars = closed?.chars ?? atomChars(atom)
        var (first, last) = (chars, chars)
        if let closed {
            let (lead, tail) = closed.separators
            if lead == nil && tail == nil && closed.repeats(quantifier) { return .done(.nested) }
            (first, last) = (lead ?? chars, tail ?? chars)
            groups[current].inner = groups[current].inner || closed.inner
            groups[current].unbounded = groups[current].unbounded || closed.unbounded
        }
        groups[current].chars += chars
        groups[current].parts.append(Part(chars: chars, quantifier: quantifier, atom: closed == nil))
        if let closed, closed.look || !quantifier.present {
            groups[current].previous = closed.look || closed.alternated ? [] : closed.previous
            return .next
        }
        groups[current].inner = groups[current].inner || !quantifier.exact
        groups[current].unbounded = groups[current].unbounded || quantifier.unbounded
        switch trailing(groups[current].previous, quantifier, first: first, last: last) {
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
    guard units.count <= 1000 else { return .long }
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

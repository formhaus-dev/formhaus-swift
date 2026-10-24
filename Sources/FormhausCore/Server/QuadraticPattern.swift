private func asciiSet(_ text: String) -> AsciiSet {
    var set = AsciiSet()
    for unit in text.utf16 { set.insert(unit) }
    return set
}

private let punctuation = asciiSet("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
private let special = asciiSet(".^$|()[]{}*+?\\")
private let classEscapes = asciiSet("dws")
private let quantifiers = asciiSet("+*?")
private let followers = asciiSet("+*?{")
private let groupFollowers = asciiSet("?*+{")

private enum Repeat {
    case once, optional, plus, star
}

private struct Item {
    let chars: AsciiSet
    let repeats: Repeat
}

private struct QuadraticScanner {
    let units: [UInt16]

    func unit(_ index: Int) -> UInt16? {
        index < units.count ? units[index] : nil
    }

    private func isPrintable(_ char: UInt16) -> Bool {
        (0x20...0x7E).contains(char)
    }

    private func escapeEnd(at index: Int) -> Int? {
        guard let next = unit(index + 1), punctuation.contains(next) || classEscapes.contains(next) else { return nil }
        return index + 2
    }

    private func classMember(at index: Int) -> Int? {
        guard let char = unit(index) else { return nil }
        if char == code("\\") { return escapeEnd(at: index) }
        return char != code("]") && isPrintable(char) ? index + 1 : nil
    }

    private func single(_ from: Int, _ to: Int) -> Bool {
        to - from == 1 || !classEscapes.contains(units[from + 1])
    }

    private func classEnd(from start: Int) -> Int? {
        var index = start + 1
        if unit(index) == code("^") || unit(index) == code("]") { return nil }
        while unit(index) != code("]") {
            guard let end = classMember(at: index) else { return nil }
            guard unit(end) == code("-"), let after = unit(end + 1), after != code("]") else {
                index = end
                continue
            }
            guard let last = classMember(at: end + 1), single(index, end), single(end + 1, last) else { return nil }
            if units[end - 1] > units[last - 1] { return nil }
            index = last
        }
        return index + 1
    }

    func atomEnd(at index: Int) -> Int? {
        guard let char = unit(index) else { return nil }
        if char == code("[") { return classEnd(from: index) }
        if char == code("\\") { return escapeEnd(at: index) }
        return isPrintable(char) && !special.contains(char) ? index + 1 : nil
    }

    func opening(at index: Int) -> Int {
        if unit(index) == code("("), unit(index + 1) == code("?"), unit(index + 2) == code(":") { return 3 }
        return unit(index) == code("(") && unit(index + 1) != code("?") ? 1 : 0
    }
}

private func repeatKind(_ unit: UInt16) -> Repeat {
    switch unit {
    case code("+"): .plus
    case code("*"): .star
    default: .optional
    }
}

private func items(_ units: [UInt16]) -> [Item]? {
    guard units.first == code("^") else { return nil }
    let scanner = QuadraticScanner(units: units)
    let anchored = units.last == code("$") && !(units.count >= 2 && units[units.count - 2] == code("\\"))
    let end = anchored ? units.count - 1 : units.count
    var result: [Item] = []
    var grouped = false
    var index = 1
    while index < end {
        let open = scanner.opening(at: index)
        if open > 0 {
            if grouped { return nil }
            (grouped, index) = (true, index + open)
            continue
        }
        if units[index] == code(")") {
            guard grouped, let next = scanner.unit(index + 1), !groupFollowers.contains(next) else { return nil }
            (grouped, index) = (false, index + 1)
            continue
        }
        guard let atomStop = scanner.atomEnd(at: index), atomStop <= end else { return nil }
        let quantified = atomStop < end && quantifiers.contains(units[atomStop])
        let next = atomStop + (quantified ? 1 : 0)
        if quantified && next < end && followers.contains(units[next]) { return nil }
        if !quantified && scanner.unit(atomStop) == code("{") { return nil }
        let atom = String(decoding: units[index..<atomStop], as: UTF16.self)
        result.append(Item(chars: asciiMatches("^\(atom)$"), repeats: quantified ? repeatKind(units[atomStop]) : .once))
        index = next
    }
    return grouped ? nil : result
}

func isQuadratic(_ units: [UInt16]) -> Bool {
    guard let sequence = items(units) else { return false }
    var previous = AsciiSet()
    var overlaps = 0
    var optionalOverlaps = 0
    for item in sequence {
        let overlapping = item.chars.intersects(previous)
        switch item.repeats {
        case .plus, .star:
            if overlapping { overlaps += 1 }
            previous = item.repeats == .star ? previous.union(item.chars) : item.chars
        case .optional:
            if overlapping { optionalOverlaps += 1 }
            previous = previous.union(item.chars)
        case .once:
            if overlapping { return false }
            previous = AsciiSet()
        }
    }
    return overlaps == 1 && optionalOverlaps <= 1
}

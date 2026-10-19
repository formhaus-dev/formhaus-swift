extension RegexParser {
    mutating func parseAtom() throws(RegexSyntaxError) -> Atom {
        let unit = units[index]
        index += 1
        switch scalar(unit) {
        case "^": return Atom(node: .assertion(modifiers.multiline ? .lineStart : .inputStart), quantifiable: false)
        case "$": return Atom(node: .assertion(modifiers.multiline ? .lineEnd : .inputEnd), quantifiable: false)
        case ".": return Atom(node: .set(modifiers.dotAll ? .all : .dot), quantifiable: true)
        case "(": return try parseGroup()
        case "[": return Atom(node: try parseClass(), quantifiable: true)
        case "\\": return try parseAtomEscape()
        case "*", "+", "?": throw RegexSyntaxError()
        case "{":
            guard !isBracedQuantifier(at: index - 1) else { throw RegexSyntaxError() }
            return literal(unit)
        default: return literal(unit)
        }
    }

    func literal(_ unit: UInt16) -> Atom {
        guard modifiers.ignoreCase else { return Atom(node: .unit(unit), quantifiable: true) }
        let folded = CaseFolding.fold(CharSet(unit: unit))
        return Atom(node: folded.singleUnit.map(RegexNode.unit) ?? .set(folded), quantifiable: true)
    }

    func setAtom(_ set: CharSet) -> Atom {
        Atom(node: .set(modifiers.ignoreCase ? CaseFolding.fold(set) : set), quantifiable: true)
    }

    private mutating func parseGroup() throws(RegexSyntaxError) -> Atom {
        guard consume("?") else { return try parseCapture(name: nil) }
        if consume(":") { return Atom(node: .group(try parseGroupBody(), capture: nil), quantifiable: true) }
        if at("=") || at("!") {
            let negated = at("!")
            index += 1
            return Atom(node: .look(try parseGroupBody(), Look(behind: false, negated: negated)), quantifiable: true)
        }
        if at("<"), at("=", 1) || at("!", 1) {
            let negated = at("!", 1)
            index += 2
            return Atom(node: .look(try parseGroupBody(), Look(behind: true, negated: negated)), quantifiable: false)
        }
        if at("<") {
            guard let name = parseGroupName(units, from: index + 1) else { throw RegexSyntaxError() }
            index = name.end
            return try parseCapture(name: name.name)
        }
        return Atom(node: try parseModified(), quantifiable: true)
    }

    private mutating func parseGroupBody(capture: Int? = nil, name: String? = nil) throws(RegexSyntaxError) -> RegexNode {
        let savedIndex = groupIndex
        let savedInterval = interval
        defer {
            groupIndex = savedIndex
            interval = savedInterval
        }
        if let capture { groupIndex = capture }
        let body = try parseDisjunction()
        guard consume(")") else { throw RegexSyntaxError() }
        if let name, let capture {
            guard named.allSatisfy({ $0.name != name || interval.contains($0.index) }) else { throw RegexSyntaxError() }
            named.append(NamedGroup(name: name, index: capture))
        }
        return body
    }

    private mutating func parseCapture(name: String?) throws(RegexSyntaxError) -> Atom {
        captures += 1
        let capture = captures
        return Atom(node: .group(try parseGroupBody(capture: capture, name: name), capture: capture), quantifiable: true)
    }

    private mutating func parseModified() throws(RegexSyntaxError) -> RegexNode {
        let added = modifierFlags()
        let removed = consume("-") ? modifierFlags() : nil
        let flags = added + (removed ?? [])
        guard consume(":"), Set(flags).count == flags.count, removed == nil || !flags.isEmpty else { throw RegexSyntaxError() }
        let saved = modifiers
        defer { modifiers = saved }
        for flag in added { setModifier(flag, true) }
        for flag in removed ?? [] { setModifier(flag, false) }
        return .group(try parseGroupBody(), capture: nil)
    }

    private mutating func modifierFlags() -> [UInt16] {
        var flags: [UInt16] = []
        while let unit = peek(), at("i") || at("m") || at("s") {
            flags.append(unit)
            index += 1
        }
        return flags
    }

    private mutating func setModifier(_ flag: UInt16, _ value: Bool) {
        switch scalar(flag) {
        case "i": modifiers.ignoreCase = value
        case "m": modifiers.multiline = value
        default: modifiers.dotAll = value
        }
    }
}

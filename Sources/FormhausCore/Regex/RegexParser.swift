struct ParsedPattern {
    let root: RegexNode
    let captureCount: Int
}

struct RegexParser {
    struct Atom {
        let node: RegexNode
        let quantifiable: Bool
    }

    struct NamedGroup {
        let name: String
        let index: Int
    }

    private struct Bounds {
        let min: Int
        let max: Int?
        let end: Int
    }

    static let maxDepth = 100
    private static let infinity = Int(Int32.max)

    let units: [UInt16]
    let groups: CaptureScan
    var index = 0
    var modifiers = RegexModifiers()
    var captures = 0
    var looks = 0
    var depth = 0
    var scope = NameScope(start: 0)
    var named: [NamedGroup] = []

    private init(_ units: [UInt16]) {
        self.units = units
        groups = CaptureScan(units)
    }

    static func parse(_ source: String) throws(RegexSyntaxError) -> ParsedPattern {
        var parser = RegexParser(Array(source.utf16))
        let root = try parser.parseDisjunction()
        guard parser.index == parser.units.count else { throw RegexSyntaxError() }
        return ParsedPattern(root: root, captureCount: parser.captures)
    }

    func peek(_ offset: Int = 0) -> UInt16? {
        index + offset < units.count ? units[index + offset] : nil
    }

    func at(_ scalar: Unicode.Scalar, _ offset: Int = 0) -> Bool {
        peek(offset) == UInt16(scalar.value)
    }

    mutating func consume(_ scalar: Unicode.Scalar) -> Bool {
        guard at(scalar) else { return false }
        index += 1
        return true
    }

    mutating func parseDisjunction() throws(RegexSyntaxError) -> RegexNode {
        depth += 1
        defer { depth -= 1 }
        guard depth <= Self.maxDepth else { throw RegexSyntaxError() }
        var branches = [try parseAlternative()]
        while consume("|") {
            scope.addAlternative(captures: captures)
            branches.append(try parseAlternative())
        }
        return branches.count == 1 ? branches[0] : .alternation(branches)
    }

    private mutating func parseAlternative() throws(RegexSyntaxError) -> RegexNode {
        var terms: [RegexNode] = []
        while peek() != nil, !at("|"), !at(")") {
            terms.append(try parseTerm())
        }
        return terms.count == 1 ? terms[0] : .sequence(terms)
    }

    private mutating func parseTerm() throws(RegexSyntaxError) -> RegexNode {
        let atom = try parseAtom()
        guard let quantifier = try parseQuantifier() else { return atom.node }
        guard atom.quantifiable else { throw RegexSyntaxError() }
        return .quantified(atom.node, quantifier)
    }

    private mutating func parseQuantifier() throws(RegexSyntaxError) -> Quantifier? {
        guard let unit = peek() else { return nil }
        let bounds: Bounds
        switch scalar(unit) {
        case "*": bounds = Bounds(min: 0, max: nil, end: index + 1)
        case "+": bounds = Bounds(min: 1, max: nil, end: index + 1)
        case "?": bounds = Bounds(min: 0, max: 1, end: index + 1)
        case "{":
            guard let braced = bracedBounds(at: index) else { return nil }
            bounds = braced
        default: return nil
        }
        if let max = bounds.max, max < bounds.min { throw RegexSyntaxError() }
        index = bounds.end
        return Quantifier(min: bounds.min, max: bounds.max, greedy: !consume("?"))
    }

    func isBracedQuantifier(at start: Int) -> Bool {
        bracedBounds(at: start) != nil
    }

    private func bracedBounds(at start: Int) -> Bounds? {
        var cursor = start + 1
        guard let min = number(&cursor) else { return nil }
        var max: Int? = min
        if cursor < units.count, units[cursor] == UInt16(ascii: ",") {
            cursor += 1
            max = number(&cursor) ?? Self.infinity
        }
        guard cursor < units.count, units[cursor] == UInt16(ascii: "}") else { return nil }
        return Bounds(min: min, max: max == Self.infinity ? nil : max, end: cursor + 1)
    }

    private func number(_ cursor: inout Int) -> Int? {
        let start = cursor
        var value = 0
        while cursor < units.count, let digit = decimalDigit(units[cursor]) {
            value = min(value * 10 + digit, Self.infinity)
            cursor += 1
        }
        return cursor > start ? value : nil
    }
}

func scalar(_ unit: UInt16) -> Unicode.Scalar {
    Unicode.Scalar(unit) ?? "\u{FFFD}"
}

func decimalDigit(_ unit: UInt16) -> Int? {
    (0x30...0x39).contains(unit) ? Int(unit) - 0x30 : nil
}

enum SearchPlan: Sendable {
    case forward
    case fromEnd
    case suffix(LiteralSearch)

    init(_ root: RegexNode, automaton: Bool, anchored: Bool) {
        guard automaton, !anchored else {
            self = .forward
            return
        }
        if Self.endAnchored(root) {
            self = .fromEnd
            return
        }
        let suffix = Self.suffix(root).suffix(Prefilter.literalLimit)
        self = suffix.isEmpty ? .forward : .suffix(LiteralSearch(Array(suffix)))
    }

    var backward: Bool {
        if case .forward = self { return false }
        return true
    }

    func end(in text: [UInt16], after previous: Int?) -> Int? {
        switch self {
        case .forward: return nil
        case .fromEnd: return previous == nil ? text.count : nil
        case .suffix(let search):
            let length = search.literal.count
            return search.index(in: text, from: previous.map { $0 - length + 1 } ?? 0).map { $0 + length }
        }
    }

    private static func endAnchored(_ node: RegexNode) -> Bool {
        switch node {
        case .assertion(let assertion): assertion == .inputEnd
        case .sequence(let nodes): nodes.last(where: { !$0.isVoid }).map(endAnchored) ?? false
        case .alternation(let nodes): nodes.allSatisfy(endAnchored)
        case .group(let body, _): endAnchored(body)
        case .quantified(let body, let quantifier): quantifier.min > 0 && endAnchored(body)
        default: false
        }
    }

    private static func suffix(_ node: RegexNode) -> [UInt16] {
        switch node {
        case .unit(let unit): return [unit]
        case .group(let body, _): return suffix(body)
        case .sequence(let nodes):
            var literal: [UInt16] = []
            for node in nodes.reversed() where !node.isVoid {
                literal = suffix(node) + literal
                guard node.isLiteral, literal.count < Prefilter.literalLimit else { break }
            }
            return literal
        default: return []
        }
    }
}

extension RegexNode {
    var isVoid: Bool {
        if case .quantified(_, let quantifier) = self { return quantifier.max == 0 }
        return false
    }

    var isLiteral: Bool {
        switch self {
        case .unit: true
        case .group(let body, _): body.isLiteral
        case .sequence(let nodes): nodes.allSatisfy { $0.isVoid || $0.isLiteral }
        default: false
        }
    }
}

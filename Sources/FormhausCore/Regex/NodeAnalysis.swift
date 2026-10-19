extension RegexNode {
    var children: [RegexNode] {
        switch self {
        case .sequence(let nodes), .alternation(let nodes): nodes
        case .group(let body, _), .quantified(let body, _), .look(let body, _): [body]
        default: []
        }
    }

    func contains(where predicate: (RegexNode) -> Bool) -> Bool {
        predicate(self) || children.contains { $0.contains(where: predicate) }
    }

    var captureRange: ClosedRange<Int>? {
        var bounds: ClosedRange<Int>?
        if case .group(_, let capture?) = self { bounds = capture...capture }
        for child in children {
            guard let inner = child.captureRange else { continue }
            bounds = bounds.map { min($0.lowerBound, inner.lowerBound)...max($0.upperBound, inner.upperBound) } ?? inner
        }
        return bounds
    }

    var canBeEmpty: Bool {
        switch self {
        case .unit, .set: false
        case .sequence(let nodes): nodes.allSatisfy(\.canBeEmpty)
        case .alternation(let nodes): nodes.contains(where: \.canBeEmpty)
        case .group(let body, _): body.canBeEmpty
        case .quantified(let body, let quantifier): quantifier.min == 0 || body.canBeEmpty
        case .assertion, .look, .backreference: true
        }
    }

    var isCounted: Bool {
        guard case .quantified(_, let quantifier) = self else { return false }
        return quantifier.min > 1 || (quantifier.max ?? 0) > 1
    }

    var expandedSize: Double {
        switch self {
        case .sequence(let nodes): nodes.reduce(0) { $0 + $1.expandedSize }
        case .alternation(let nodes): nodes.reduce(0) { $0 + $1.expandedSize + 2 }
        case .group(let body, _), .look(let body, _): body.expandedSize + 2
        case .quantified(let body, let quantifier):
            Double(quantifier.max ?? quantifier.min + 1) * (body.expandedSize + 4)
        default: 1
        }
    }
}

extension RegexNode {
    var children: [RegexNode] {
        switch self {
        case .sequence(let nodes), .alternation(let nodes): nodes
        case .group(let body, _), .quantified(let body, _), .look(let body, _): [body]
        default: []
        }
    }

    func contains(where predicate: (RegexNode) -> Bool) -> Bool {
        if predicate(self) { return true }
        switch self {
        case .sequence(let nodes), .alternation(let nodes): return nodes.contains { $0.contains(where: predicate) }
        case .group(let body, _), .quantified(let body, _), .look(let body, _): return body.contains(where: predicate)
        default: return false
        }
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

    var minimumLength: Int {
        switch self {
        case .unit, .set: 1
        case .sequence(let nodes): nodes.reduce(0) { saturatingSum($0, $1.minimumLength) }
        case .alternation(let nodes): nodes.map(\.minimumLength).min() ?? 0
        case .group(let body, _): body.minimumLength
        case .quantified(let body, let quantifier):
            body.minimumLength == 0
                ? 0 : quantifier.min > Int(Int32.max) / body.minimumLength ? Int(Int32.max) : quantifier.min * body.minimumLength
        case .assertion, .look, .backreference: 0
        }
    }
}

private func saturatingSum(_ first: Int, _ second: Int) -> Int {
    min(first + second, Int(Int32.max))
}

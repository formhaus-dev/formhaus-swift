struct Prefilter: Sendable {
    private struct First {
        let set: CharSet
        let nullable: Bool
    }

    private static let literalLimit = 64

    let required: [UInt16]
    let anchored: Bool
    let first: CharSet?

    init(_ root: RegexNode) {
        required = Self.required(root)
        anchored = Self.anchored(root)
        let first = Self.first(root)
        self.first = first?.nullable == false ? first?.set : nil
    }

    func admits(_ text: [UInt16]) -> Bool {
        guard let lead = required.first else { return true }
        guard text.count >= required.count else { return false }
        return text.withUnsafeBufferPointer { text in
            required.withUnsafeBufferPointer { required in
                var start = 0
                let last = text.count - required.count
                while start <= last {
                    if text[start] == lead, (1..<required.count).allSatisfy({ text[start + $0] == required[$0] }) { return true }
                    start += 1
                }
                return false
            }
        }
    }

    private static func anchored(_ node: RegexNode) -> Bool {
        switch node {
        case .assertion(let assertion): assertion == .inputStart
        case .sequence(let nodes): nodes.first.map(anchored) ?? false
        case .alternation(let nodes): nodes.allSatisfy(anchored)
        case .group(let body, _): anchored(body)
        case .quantified(let body, let quantifier): quantifier.min > 0 && anchored(body)
        default: false
        }
    }

    private static func first(_ node: RegexNode) -> First? {
        switch node {
        case .unit(let unit): First(set: CharSet(unit: unit), nullable: false)
        case .set(let set): First(set: set, nullable: false)
        case .sequence(let nodes): sequenceFirst(nodes)
        case .alternation(let nodes): alternationFirst(nodes)
        case .group(let body, _): first(body)
        case .quantified(_, let quantifier) where quantifier.max == 0: First(set: CharSet([]), nullable: true)
        case .quantified(let body, let quantifier):
            first(body).map { First(set: $0.set, nullable: $0.nullable || quantifier.min == 0) }
        case .assertion, .look: First(set: CharSet([]), nullable: true)
        case .backreference: nil
        }
    }

    private static func sequenceFirst(_ nodes: [RegexNode]) -> First? {
        var set = CharSet([])
        for node in nodes {
            guard let next = first(node) else { return nil }
            set = set.union(next.set)
            if !next.nullable { return First(set: set, nullable: false) }
        }
        return First(set: set, nullable: true)
    }

    private static func alternationFirst(_ nodes: [RegexNode]) -> First? {
        var set = CharSet([])
        var nullable = false
        for node in nodes {
            guard let next = first(node) else { return nil }
            set = set.union(next.set)
            nullable = nullable || next.nullable
        }
        return First(set: set, nullable: nullable)
    }

    private static func exact(_ node: RegexNode) -> [UInt16]? {
        switch node {
        case .unit(let unit): return [unit]
        case .assertion, .look: return []
        case .group(let body, _): return exact(body)
        case .sequence(let nodes):
            var literal: [UInt16] = []
            for node in nodes {
                guard let part = exact(node), literal.count + part.count <= literalLimit else { return nil }
                literal += part
            }
            return literal
        default: return nil
        }
    }

    private static func required(_ node: RegexNode) -> [UInt16] {
        if let literal = exact(node) { return literal }
        switch node {
        case .group(let body, _): return required(body)
        case .quantified(let body, let quantifier): return quantifier.min > 0 ? required(body) : []
        case .look(let body, let look): return look.negated ? [] : required(body)
        case .sequence(let nodes):
            var best: [UInt16] = []
            var run: [UInt16] = []
            for node in nodes {
                if let part = exact(node), run.count + part.count <= literalLimit {
                    run += part
                    continue
                }
                best = longer(longer(best, run), required(node))
                run = exact(node) ?? []
            }
            return longer(best, run)
        default: return []
        }
    }

    private static func longer(_ first: [UInt16], _ second: [UInt16]) -> [UInt16] {
        second.count > first.count ? second : first
    }
}

indirect enum RegexNode: Sendable {
    case unit(UInt16)
    case set(CharSet)
    case sequence([RegexNode])
    case alternation([RegexNode])
    case group(RegexNode, capture: Int?)
    case quantified(RegexNode, Quantifier)
    case assertion(RegexAssertion)
    case look(RegexNode, Look)
    case backreference([Int], ignoreCase: Bool)
}

struct Quantifier: Sendable {
    let min: Int
    let max: Int?
    let greedy: Bool
}

struct Look: Sendable, Hashable {
    let behind: Bool
    let negated: Bool
    let index: Int
}

enum RegexAssertion: Sendable, Hashable {
    case inputStart
    case inputEnd
    case lineStart
    case lineEnd
    case wordBoundary
    case notWordBoundary
}

struct RegexModifiers: Sendable, Hashable {
    var ignoreCase = false
    var multiline = false
    var dotAll = false
}

struct RegexSyntaxError: Error {}

enum Instruction: Sendable {
    case unit(UInt16, backward: Bool)
    case set(Int, backward: Bool)
    case split(Int, Int)
    case jump(Int)
    case assertion(RegexAssertion)
    case state(StateChange)
    case repeatSet(RepeatSet)
    case backreference(Int)
    case look(Int)
    case succeed
    case match
}

enum StateChange: Sendable {
    case groupStart(Int)
    case groupEnd(Int)
    case clear(ClosedRange<Int>)
    case mark(Int)
    case progress(Int)
}

struct RepeatSet: Sendable {
    let set: Int
    let min: Int
    let max: Int?
    let greedy: Bool
    let backward: Bool
}

struct Backreference: Sendable {
    let groups: [Int]
    let backward: Bool
    let ignoreCase: Bool
}

struct LookBody: Sendable {
    let look: Look
    let start: Int?
}

struct RegexProgram: Sendable {
    let instructions: [Instruction]
    let sets: [CharSet]
    let looks: [LookBody]
    let scans: [RegexProgram?]
    let size: Int
    let references: [Backreference]
    let captureCount: Int
    let registerCount: Int
    let mainEnd: Int
    let memoFrom: Int
    let automaton: Bool

    func consumes(_ pc: Int, _ unit: UInt16) -> Bool {
        if case .unit(let expected, _) = instructions[pc] { return expected == unit }
        if case .set(let index, _) = instructions[pc] { return sets[index].contains(unit) }
        return false
    }
}

enum UnitContext: Sendable, Hashable {
    case edge
    case word
    case lineTerminator
    case other

    init(_ unit: UInt16) {
        if CharSet.word.contains(unit) {
            self = .word
        } else if CharSet.lineTerminator.contains(unit) {
            self = .lineTerminator
        } else {
            self = .other
        }
    }
}

extension RegexAssertion {
    func holds(before: UnitContext, after: UnitContext) -> Bool {
        switch self {
        case .inputStart: before == .edge
        case .inputEnd: after == .edge
        case .lineStart: before == .edge || before == .lineTerminator
        case .lineEnd: after == .edge || after == .lineTerminator
        case .wordBoundary: (before == .word) != (after == .word)
        case .notWordBoundary: (before == .word) == (after == .word)
        }
    }
}

struct MatchInput {
    let text: [UInt16]

    func unit(at position: Int, backward: Bool) -> UInt16? {
        if backward { return position > 0 ? text[position - 1] : nil }
        return position < text.count ? text[position] : nil
    }

    func holds(_ assertion: RegexAssertion, at position: Int) -> Bool {
        if assertion == .inputStart { return position == 0 }
        if assertion == .inputEnd { return position == text.count }
        let before = position > 0 ? UnitContext(text[position - 1]) : .edge
        let after = position < text.count ? UnitContext(text[position]) : .edge
        return assertion.holds(before: before, after: after)
    }
}

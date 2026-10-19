enum Instruction: Sendable {
    case unit(UInt16, backward: Bool)
    case set(Int, backward: Bool)
    case split(Int, Int)
    case jump(Int)
    case assertion(RegexAssertion)
    case groupStart(Int)
    case groupEnd(Int)
    case clear(ClosedRange<Int>)
    case mark(Int)
    case progress(Int)
    case counterStart(Int)
    case repeatSet(RepeatSet)
    case counterLoop(CounterLoop)
    case counterNext(CounterNext)
    case backreference(Int)
    case look(Int)
    case succeed
    case match
}

struct CounterLoop: Sendable {
    let register: Int
    let min: Int
    let max: Int?
    let greedy: Bool
    let exit: Int
}

struct RepeatSet: Sendable {
    let set: Int
    let min: Int
    let max: Int?
    let greedy: Bool
    let backward: Bool
}

struct CounterNext: Sendable {
    let register: Int
    let mark: Int?
    let min: Int
    let loop: Int
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
    let references: [Backreference]
    let captureCount: Int
    let registerCount: Int
    let mainEnd: Int
    let memoFrom: Int
    let automaton: Bool

    func consumes(_ pc: Int, _ unit: UInt16) -> Bool {
        switch instructions[pc] {
        case .unit(let expected, _): expected == unit
        case .set(let index, _): sets[index].contains(unit)
        default: false
        }
    }

    func advance(_ instruction: Instruction, in input: MatchInput, from position: Int) -> Int? {
        switch instruction {
        case .unit(let expected, let backward):
            guard input.unit(at: position, backward: backward) == expected else { return nil }
            return position + (backward ? -1 : 1)
        case .set(let index, let backward):
            guard let unit = input.unit(at: position, backward: backward), sets[index].contains(unit) else { return nil }
            return position + (backward ? -1 : 1)
        default:
            return nil
        }
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

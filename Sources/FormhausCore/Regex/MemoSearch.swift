struct Bitset {
    private var words: [UInt64]

    init(count: Int) {
        words = Array(repeating: 0, count: (count + 63) / 64)
    }

    mutating func insert(_ index: Int) -> Bool {
        let bit: UInt64 = 1 << UInt64(index & 63)
        let old = words[index >> 6]
        words[index >> 6] = old | bit
        return old & bit == 0
    }

    mutating func remove(_ index: Int) {
        words[index >> 6] &= ~(1 << UInt64(index & 63))
    }
}

struct MemoSearch {
    static let visitedLimit = 1 << 25

    private enum Step {
        case next(Int, Int)
        case dead
        case success
    }

    private let program: RegexProgram
    private let input: MatchInput
    private let width: Int
    private var visited: [Bitset?]
    private var results: [[UInt8]?]
    private var log: [Int] = []

    init?(_ program: RegexProgram, _ input: MatchInput) {
        width = input.text.count + 1
        let largest = program.looks.filter(\.pure).map { $0.end - $0.start + 1 }.max() ?? 0
        guard largest * width <= Self.visitedLimit else { return nil }
        self.program = program
        self.input = input
        visited = Array(repeating: nil, count: program.looks.count)
        results = Array(repeating: nil, count: program.looks.count)
    }

    mutating func evaluate(_ index: Int, at position: Int, budget: inout StepBudget) throws(BudgetExceeded) -> Bool {
        if let known = results[index]?[position], known != 0 { return known == 1 }
        if results[index] == nil { results[index] = Array(repeating: 0, count: width) }
        let found = try search(index, from: position, &budget)
        results[index]?[position] = found ? 1 : 2
        return found
    }

    private mutating func search(_ index: Int, from position: Int, _ budget: inout StepBudget) throws(BudgetExceeded) -> Bool {
        let look = program.looks[index]
        if visited[index] == nil { visited[index] = Bitset(count: (look.end - look.start + 1) * width) }
        let mark = log.count
        var pending = [(look.start, position)]
        while let (pc, offset) = pending.popLast() {
            var state = Step.next(pc, offset)
            while case .next(let pc, let offset) = state {
                let bit = (pc - look.start) * width + offset
                guard visited[index]?.insert(bit) == true else { break }
                log.append(bit)
                try budget.spend(1)
                state = try step(pc, offset, &pending, &budget)
            }
            if case .success = state {
                for bit in log[mark...] { visited[index]?.remove(bit) }
                log.removeSubrange(mark...)
                return true
            }
        }
        log.removeSubrange(mark...)
        return false
    }

    private mutating func step(
        _ pc: Int, _ position: Int, _ pending: inout [(Int, Int)], _ budget: inout StepBudget
    ) throws(BudgetExceeded) -> Step {
        let instruction = program.instructions[pc]
        switch instruction {
        case .unit, .set:
            guard let next = program.advance(instruction, in: input, from: position) else { return .dead }
            return .next(pc + 1, next)
        case .split(let first, let second):
            pending.append((second, position))
            return .next(first, position)
        case .jump(let target): return .next(target, position)
        case .assertion(let assertion): return input.holds(assertion, at: position) ? .next(pc + 1, position) : .dead
        case .look(let index):
            return try evaluate(index, at: position, budget: &budget) != program.looks[index].look.negated ? .next(pc + 1, position) : .dead
        case .succeed, .match: return .success
        default: return .next(pc + 1, position)
        }
    }
}

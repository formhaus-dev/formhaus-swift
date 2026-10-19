struct Backtracker {
    enum Frame {
        case resume(Int, Int)
        case register(Int, Int)
        case capture(Int, Int, Int)
        case captures(Int)
        case scan(Scan)
        case extend(Scan)
    }

    struct Scan {
        let pc: Int
        let position: Int
        let stop: Int
        let step: Int
    }

    enum Outcome {
        case proceed
        case success
        case failure
    }

    static let memoLimit = 1 << 25

    let program: RegexProgram
    let input: MatchInput
    var slots: [Int]
    var registers: [Int]
    var stack: [Frame] = []
    var saved: [[Int]] = []
    var budget: StepBudget
    var memo: Bitset?
    var pureLooks: MemoSearch?
    let width: Int

    init(_ program: RegexProgram, _ input: MatchInput, budget: StepBudget) {
        self.program = program
        self.input = input
        self.budget = budget
        width = input.text.count + 1
        slots = Array(repeating: -1, count: 2 * (program.captureCount + 1))
        registers = Array(repeating: -1, count: program.registerCount)
        let region = program.mainEnd - program.memoFrom
        memo = region > 0 && region * width <= Self.memoLimit ? Bitset(count: region * width) : nil
        pureLooks = MemoSearch(program, input)
    }

    mutating func search(_ prefilter: Prefilter) throws(BudgetExceeded) -> Bool {
        let text = input.text
        for start in 0...text.count {
            if prefilter.anchored && start > 0 { return false }
            if let first = prefilter.first, start == text.count || !first.contains(text[start]) { continue }
            if try run(0, start) { return true }
        }
        return false
    }

    mutating func run(_ entry: Int, _ position: Int) throws(BudgetExceeded) -> Bool {
        let base = stack.count
        var pc = entry
        var offset = position
        while true {
            try budget.spend(1)
            switch try execute(&pc, &offset) {
            case .proceed: continue
            case .success: return true
            case .failure:
                guard let (resumePC, resumeOffset) = try backtrack(to: base) else { return false }
                pc = resumePC
                offset = resumeOffset
            }
        }
    }

    private mutating func backtrack(to base: Int) throws(BudgetExceeded) -> (Int, Int)? {
        while stack.count > base {
            switch stack.removeLast() {
            case .resume(let pc, let offset): return (pc, offset)
            case .register(let index, let value): registers[index] = value
            case .capture(let group, let start, let end):
                slots[2 * group] = start
                slots[2 * group + 1] = end
            case .captures(let index):
                slots = saved[index]
                saved.removeSubrange(index...)
            case .scan(let scan): return resumeScan(scan)
            case .extend(let scan):
                if let resumed = try resumeExtend(scan) { return resumed }
            }
        }
        return nil
    }

    func memoized(_ pc: Int) -> Bool {
        memo != nil && pc >= program.memoFrom && pc < program.mainEnd
    }

    private mutating func execute(_ pc: inout Int, _ offset: inout Int) throws(BudgetExceeded) -> Outcome {
        if memoized(pc), memo?.insert((pc - program.memoFrom) * width + offset) == false { return .failure }
        let instruction = program.instructions[pc]
        switch instruction {
        case .unit, .set:
            guard let next = program.advance(instruction, in: input, from: offset) else { return .failure }
            offset = next
        case .split(let first, let second):
            stack.append(.resume(second, offset))
            pc = first
            return .proceed
        case .jump(let target):
            pc = target
            return .proceed
        case .assertion(let assertion):
            guard input.holds(assertion, at: offset) else { return .failure }
        case .look(let index):
            guard try evaluateLook(index, offset) else { return .failure }
        case .backreference(let index):
            guard let next = try matchReference(program.references[index], offset) else { return .failure }
            offset = next
        case .succeed, .match:
            return .success
        case .counterLoop(let loop):
            return enterLoop(loop, &pc, offset)
        case .counterNext(let next):
            return continueLoop(next, &pc, offset)
        case .repeatSet(let repeated):
            guard let next = try enterRepeat(repeated, pc, offset) else { return .failure }
            offset = next
        default:
            guard try updateState(instruction, pc, offset) else { return .failure }
        }
        pc += 1
        return .proceed
    }
}

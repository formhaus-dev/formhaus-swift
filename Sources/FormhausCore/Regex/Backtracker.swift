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
    let text: [UInt16]
    var slots: [Int]
    var registers: [Int]
    var stack: [Frame] = []
    var saved: [[Int]] = []
    let context: MatchContext
    var memo: Bitset?
    let width: Int

    init(_ program: RegexProgram, _ context: MatchContext) {
        self.program = program
        text = context.text
        self.context = context
        width = text.count + 1
        slots = Array(repeating: -1, count: 2 * (program.captureCount + 1))
        registers = Array(repeating: -1, count: program.registerCount)
        let region = program.mainEnd - program.memoFrom
        memo = region > 0 && region * width <= Self.memoLimit ? Bitset(count: region * width) : nil
    }

    mutating func search(_ prefilter: Prefilter) throws(BudgetExceeded) -> Bool {
        for start in 0...(text.count - prefilter.minimumLength) {
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
            try context.spend(1)
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
            case .scan(let scan): return try resumeScan(scan)
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
        switch program.instructions[pc] {
        case .unit, .set:
            return try consume(&pc, &offset) ? .proceed : .failure
        case .split(let first, let second):
            if case .match = program.instructions[second] { return .success }
            stack.append(.resume(second, offset))
            pc = first
            return .proceed
        case .jump(let target):
            pc = target
            return .proceed
        case .assertion(let assertion):
            guard text.holds(assertion, at: offset) else { return .failure }
        case .look(let index):
            guard try evaluateLook(index, offset) else { return .failure }
        case .backreference(let index):
            guard let next = try matchReference(program.references[index], offset) else { return .failure }
            offset = next
        case .succeed, .match:
            return .success
        case .repeatSet(let repeated):
            guard let next = try enterRepeat(repeated, pc, offset) else { return .failure }
            offset = next
        case .state(let change):
            guard try apply(change, pc, offset) else { return .failure }
        }
        pc += 1
        return .proceed
    }

    private mutating func consume(_ pc: inout Int, _ offset: inout Int) throws(BudgetExceeded) -> Bool {
        var steps = 0
        var matched = true
        run: while steps == 0 || memo == nil {
            let step: Int
            switch program.instructions[pc] {
            case .unit(let expected, let backward):
                matched = text.nextUnit(from: offset, backward: backward) == expected
                step = backward ? -1 : 1
            case .set(let index, let backward):
                matched = text.nextUnit(from: offset, backward: backward).map(program.sets[index].contains) ?? false
                step = backward ? -1 : 1
            default: break run
            }
            guard matched else { break }
            offset += step
            pc += 1
            steps += 1
        }
        try context.spend(Swift.max(steps - 1, 0))
        return matched
    }
}

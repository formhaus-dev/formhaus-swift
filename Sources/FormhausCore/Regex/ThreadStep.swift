struct ThreadStep: Sendable {
    struct Advance {
        var next: [Int32] = []
        var accepts = false
        var volatile = false
    }

    let program: RegexProgram
    let anchored: Bool
    let backward: Bool
    let scanning: Bool
    private var seen: [UInt32]
    private var generation: UInt32 = 0
    private var stack: [Int32] = []
    private var consumers: [Int32] = []

    init(_ program: RegexProgram, anchored: Bool, backward: Bool, scanning: Bool) {
        self.program = program
        self.anchored = anchored
        self.backward = backward
        self.scanning = scanning
        seen = Array(repeating: 0, count: program.instructions.count)
    }

    mutating func advance(
        _ pcs: [Int32], _ previous: UnitContext, _ unit: UInt16?, at position: Int, _ context: MatchContext
    ) throws(BudgetExceeded) -> Advance {
        let current = unit.map(UnitContext.init) ?? .edge
        var result = try closure(pcs, before: backward ? current : previous, after: backward ? previous : current, at: position, context)
        guard !result.accepts || scanning, let unit else { return result }
        result.next.reserveCapacity(consumers.count + 1)
        for pc in consumers where program.consumes(Int(pc), unit) { result.next.append(pc + 1) }
        if !anchored { result.next.append(0) }
        return result
    }

    private mutating func closure(
        _ pcs: [Int32], before: UnitContext, after: UnitContext, at position: Int, _ context: MatchContext
    ) throws(BudgetExceeded) -> Advance {
        generation &+= 1
        if generation == 0 {
            seen = Array(repeating: 0, count: seen.count)
            generation = 1
        }
        var advance = Advance()
        consumers.removeAll(keepingCapacity: true)
        stack.removeAll(keepingCapacity: true)
        stack.append(contentsOf: pcs.reversed())
        var visited = 0
        while let pc = stack.popLast() {
            let index = Int(pc)
            guard seen[index] != generation else { continue }
            seen[index] = generation
            visited += 1
            switch program.instructions[index] {
            case .unit, .set: consumers.append(pc)
            case .split(let first, let second):
                stack.append(Int32(second))
                stack.append(Int32(first))
            case .jump(let target): stack.append(Int32(target))
            case .assertion(let assertion): if assertion.holds(before: before, after: after) { stack.append(pc + 1) }
            case .look(let look):
                advance.volatile = true
                if try context.holds(look, at: position) != program.looks[look].look.negated { stack.append(pc + 1) }
            case .match, .succeed: advance.accepts = true
            case .state: stack.append(pc + 1)
            case .repeatSet, .backreference:
                preconditionFailure("automaton programs have no stateful instructions")
            }
        }
        try context.spend(visited)
        return advance
    }

    mutating func matches(_ start: LazyDFA.Key, _ text: [UInt16], from offset: Int, _ context: MatchContext) throws(BudgetExceeded)
        -> Bool
    {
        var pcs = start.pcs
        var previous = start.context
        var position = offset
        while true {
            let unit = position < text.count ? text[position] : nil
            let step = try advance(pcs, previous, unit, at: position, context)
            if step.accepts { return true }
            guard let unit, !step.next.isEmpty else { return false }
            pcs = step.next
            previous = UnitContext(unit)
            position += 1
        }
    }

    mutating func acceptance(
        _ start: LazyDFA.Key, _ text: [UInt16], from offset: Int, into accepted: inout [Bool], _ context: MatchContext
    ) throws(BudgetExceeded) {
        var pcs = start.pcs
        var previous = start.context
        for step in offset...text.count {
            let position = backward ? text.count - step : step
            let unit = text.nextUnit(from: position, backward: backward)
            let result = try advance(pcs, previous, unit, at: position, context)
            accepted[position] = result.accepts
            guard let unit, !result.next.isEmpty else { return }
            pcs = result.next
            previous = UnitContext(unit)
        }
    }
}

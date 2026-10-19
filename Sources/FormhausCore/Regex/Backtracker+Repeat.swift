extension Backtracker {
    mutating func enterRepeat(_ repeated: RepeatSet, _ pc: Int, _ offset: Int) throws(BudgetExceeded) -> Int? {
        let step = repeated.backward ? -1 : 1
        let limit = repeated.greedy ? repeated.max ?? Int.max : repeated.min
        var position = offset
        var count = 0
        while count < limit, consumes(repeated, at: position) {
            position += step
            count += 1
        }
        try context.spend(count)
        guard count >= repeated.min else { return nil }
        if repeated.greedy {
            if count > repeated.min {
                stack.append(.scan(Scan(pc: pc + 1, position: position, stop: offset + step * repeated.min, step: -step)))
            }
        } else if repeated.max.map({ $0 > repeated.min }) ?? true {
            let stop = repeated.max.map { offset + step * $0 } ?? (repeated.backward ? -1 : input.text.count + 1)
            stack.append(.extend(Scan(pc: pc, position: position, stop: stop, step: step)))
        }
        return position
    }

    mutating func resumeScan(_ scan: Scan) -> (Int, Int) {
        let position = scan.position + scan.step
        if position != scan.stop { stack.append(.scan(Scan(pc: scan.pc, position: position, stop: scan.stop, step: scan.step))) }
        return (scan.pc, position)
    }

    mutating func resumeExtend(_ scan: Scan) throws(BudgetExceeded) -> (Int, Int)? {
        guard case .repeatSet(let repeated) = program.instructions[scan.pc], consumes(repeated, at: scan.position) else { return nil }
        let position = scan.position + scan.step
        try context.spend(1)
        if position != scan.stop { stack.append(.extend(Scan(pc: scan.pc, position: position, stop: scan.stop, step: scan.step))) }
        return (scan.pc + 1, position)
    }

    private func consumes(_ repeated: RepeatSet, at position: Int) -> Bool {
        guard let unit = input.unit(at: position, backward: repeated.backward) else { return false }
        return program.sets[repeated.set].contains(unit)
    }
}

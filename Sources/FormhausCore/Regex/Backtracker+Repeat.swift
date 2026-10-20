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
            let stop = repeated.max.map { offset + step * $0 } ?? (repeated.backward ? -1 : text.count + 1)
            stack.append(.extend(Scan(pc: pc, position: position, stop: stop, step: step)))
        }
        return position
    }

    mutating func resumeScan(_ scan: Scan) throws(BudgetExceeded) -> (Int, Int) {
        var position = scan.position + scan.step
        var skipped = 0
        while position != scan.stop, !mayEnter(scan.pc, at: position) {
            position += scan.step
            skipped += 1
        }
        try context.spend(skipped)
        if position != scan.stop { stack.append(.scan(Scan(pc: scan.pc, position: position, stop: scan.stop, step: scan.step))) }
        return (scan.pc, position)
    }

    mutating func resumeExtend(_ scan: Scan) throws(BudgetExceeded) -> (Int, Int)? {
        guard case .repeatSet(let repeated) = program.instructions[scan.pc] else { return nil }
        var position = scan.position
        var steps = 0
        repeat {
            guard consumes(repeated, at: position) else {
                try context.spend(steps)
                return nil
            }
            position += scan.step
            steps += 1
        } while position != scan.stop && !mayEnter(scan.pc + 1, at: position)
        try context.spend(steps)
        if position != scan.stop { stack.append(.extend(Scan(pc: scan.pc, position: position, stop: scan.stop, step: scan.step))) }
        return (scan.pc + 1, position)
    }

    private func mayEnter(_ entry: Int, at position: Int) -> Bool {
        var pc = entry
        while true {
            switch program.instructions[pc] {
            case .unit(let expected, let backward): return text.nextUnit(from: position, backward: backward) == expected
            case .set(let index, let backward):
                return text.nextUnit(from: position, backward: backward).map(program.sets[index].contains) ?? false
            case .backreference(let index): return pc != entry || mayRepeat(program.references[index], at: position)
            case .state(.progress): return true
            case .state: pc += 1
            case .jump(let target): pc = target
            default: return true
            }
        }
    }

    private func mayRepeat(_ reference: Backreference, at position: Int) -> Bool {
        guard reference.groups.count == 1 else { return true }
        let start = slots[2 * reference.groups[0]]
        let end = slots[2 * reference.groups[0] + 1]
        guard start >= 0, end > start else { return true }
        guard let next = text.nextUnit(from: position, backward: reference.backward) else { return false }
        let expected = text[reference.backward ? end - 1 : start]
        return next == expected || reference.ignoreCase && CaseFolding.canonical[Int(next)] == CaseFolding.canonical[Int(expected)]
    }

    private func consumes(_ repeated: RepeatSet, at position: Int) -> Bool {
        guard let unit = text.nextUnit(from: position, backward: repeated.backward) else { return false }
        return program.sets[repeated.set].contains(unit)
    }
}

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
}

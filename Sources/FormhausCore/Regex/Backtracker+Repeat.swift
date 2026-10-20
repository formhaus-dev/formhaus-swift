extension Backtracker {
    enum Gate {
        case open
        case unit(UInt16, backward: Bool)
        case set(CharSet, backward: Bool)
        case folded(UInt16, backward: Bool)
    }

    mutating func enterRepeat(_ repeated: RepeatSet, _ pc: Int, _ offset: Int) throws(BudgetExceeded) -> Int? {
        let step = repeated.backward ? -1 : 1
        let limit = repeated.greedy ? repeated.max ?? Int.max : repeated.min
        let members = Gate.set(program.sets[repeated.set], backward: repeated.backward)
        var position = offset
        var count = 0
        while count < limit, admits(members, at: position) {
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
        let next = gate(scan.pc)
        var position = scan.position + scan.step
        var skipped = 0
        while position != scan.stop, !admits(next, at: position) {
            position += scan.step
            skipped += 1
        }
        try context.spend(skipped)
        if position != scan.stop { stack.append(.scan(Scan(pc: scan.pc, position: position, stop: scan.stop, step: scan.step))) }
        return (scan.pc, position)
    }

    mutating func resumeExtend(_ scan: Scan) throws(BudgetExceeded) -> (Int, Int)? {
        guard case .repeatSet(let repeated) = program.instructions[scan.pc] else { return nil }
        let members = Gate.set(program.sets[repeated.set], backward: repeated.backward)
        let next = gate(scan.pc + 1)
        var position = scan.position
        var steps = 0
        repeat {
            guard admits(members, at: position) else {
                try context.spend(steps)
                return nil
            }
            position += scan.step
            steps += 1
        } while position != scan.stop && !admits(next, at: position)
        try context.spend(steps)
        if position != scan.stop { stack.append(.extend(Scan(pc: scan.pc, position: position, stop: scan.stop, step: scan.step))) }
        return (scan.pc + 1, position)
    }

    private func gate(_ entry: Int) -> Gate {
        var pc = entry
        while true {
            switch program.instructions[pc] {
            case .unit(let expected, let backward): return .unit(expected, backward: backward)
            case .set(let index, let backward): return .set(program.sets[index], backward: backward)
            case .backreference(let index) where pc == entry: return gate(program.references[index])
            case .state(.progress): return .open
            case .state: pc += 1
            case .jump(let target): pc = target
            default: return .open
            }
        }
    }

    private func gate(_ reference: Backreference) -> Gate {
        guard reference.groups.count == 1 else { return .open }
        let start = slots[2 * reference.groups[0]]
        let end = slots[2 * reference.groups[0] + 1]
        guard start >= 0, end > start else { return .open }
        let expected = text[reference.backward ? end - 1 : start]
        guard reference.ignoreCase else { return .unit(expected, backward: reference.backward) }
        return .folded(CaseFolding.canonical[Int(expected)], backward: reference.backward)
    }

    private func admits(_ gate: Gate, at position: Int) -> Bool {
        switch gate {
        case .open: true
        case .unit(let expected, let backward): text.nextUnit(from: position, backward: backward) == expected
        case .set(let set, let backward): text.nextUnit(from: position, backward: backward).map(set.contains) ?? false
        case .folded(let expected, let backward):
            text.nextUnit(from: position, backward: backward).map { CaseFolding.canonical[Int($0)] == expected } ?? false
        }
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

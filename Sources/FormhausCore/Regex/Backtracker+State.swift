extension Backtracker {
    mutating func setRegister(_ index: Int, _ value: Int) {
        guard registers[index] != value else { return }
        stack.append(.register(index, registers[index]))
        registers[index] = value
    }

    mutating func setCapture(_ group: Int, _ start: Int, _ end: Int) {
        guard slots[2 * group] != start || slots[2 * group + 1] != end else { return }
        stack.append(.capture(group, slots[2 * group], slots[2 * group + 1]))
        slots[2 * group] = start
        slots[2 * group + 1] = end
    }

    mutating func apply(_ change: StateChange, _ pc: Int, _ offset: Int) throws(BudgetExceeded) -> Bool {
        switch change {
        case .groupStart(let group), .mark(let group): setRegister(group, offset)
        case .groupEnd(let group): setCapture(group, min(registers[group], offset), max(registers[group], offset))
        case .clear(let groups):
            try context.spend(groups.count)
            for group in groups { setCapture(group, -1, -1) }
        case .progress(let register): return memoized(pc) || registers[register] != offset
        }
        return true
    }

    mutating func matchReference(_ reference: Backreference, _ offset: Int) throws(BudgetExceeded) -> Int? {
        var position = offset
        try context.spend(reference.groups.count)
        for group in reference.backward ? reference.groups : reference.groups.reversed() where slots[2 * group] >= 0 {
            try context.spend(slots[2 * group + 1] - slots[2 * group] + 1)
            guard let next = matchCapture(group, reference, position) else { return nil }
            position = next
        }
        return position
    }

    private func matchCapture(_ group: Int, _ reference: Backreference, _ offset: Int) -> Int? {
        let start = slots[2 * group]
        let length = slots[2 * group + 1] - start
        let from = reference.backward ? offset - length : offset
        guard from >= 0, from + length <= text.count else { return nil }
        for index in 0..<length {
            let left = text[start + index]
            let right = text[from + index]
            guard left == right || reference.ignoreCase && CaseFolding.canonical[Int(left)] == CaseFolding.canonical[Int(right)]
            else { return nil }
        }
        return reference.backward ? from : offset + length
    }

    mutating func evaluateLook(_ index: Int, _ offset: Int) throws(BudgetExceeded) -> Bool {
        let body = program.looks[index]
        guard let start = body.start else { return try context.holds(index, at: offset) != body.look.negated }
        try context.spend(2 * slots.count)
        let snapshot = slots
        if !body.look.negated {
            saved.append(snapshot)
            stack.append(.captures(saved.count - 1))
        }
        let base = stack.count
        let savedBase = saved.count
        let found = try run(start, offset)
        if found {
            stack.removeSubrange(base...)
            saved.removeSubrange(savedBase...)
            if body.look.negated { slots = snapshot }
        } else if !body.look.negated {
            stack.removeLast()
            saved.removeLast()
        }
        return found != body.look.negated
    }
}

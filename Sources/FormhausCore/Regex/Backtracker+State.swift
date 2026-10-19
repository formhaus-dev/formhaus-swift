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

    mutating func updateState(_ instruction: Instruction, _ pc: Int, _ offset: Int) throws(BudgetExceeded) -> Bool {
        switch instruction {
        case .groupStart(let group), .mark(let group): setRegister(group, offset)
        case .groupEnd(let group): setCapture(group, min(registers[group], offset), max(registers[group], offset))
        case .clear(let groups):
            try budget.spend(groups.count)
            for group in groups { setCapture(group, -1, -1) }
        case .progress(let register): return memoized(pc) || registers[register] != offset
        case .counterStart(let register): setRegister(register, 0)
        default: break
        }
        return true
    }

    mutating func enterLoop(_ loop: CounterLoop, _ pc: inout Int, _ offset: Int) -> Outcome {
        let count = registers[loop.register]
        if count < loop.min {
            pc += 1
        } else if let max = loop.max, count >= max {
            pc = loop.exit
        } else if loop.greedy {
            stack.append(.resume(loop.exit, offset))
            pc += 1
        } else {
            stack.append(.resume(pc + 1, offset))
            pc = loop.exit
        }
        return .proceed
    }

    mutating func continueLoop(_ next: CounterNext, _ pc: inout Int, _ offset: Int) -> Outcome {
        let count = registers[next.register]
        if let mark = next.mark, count >= next.min, registers[mark] == offset { return .failure }
        setRegister(next.register, count + 1)
        pc = next.loop
        return .proceed
    }

    mutating func matchReference(_ reference: Backreference, _ offset: Int) throws(BudgetExceeded) -> Int? {
        var position = offset
        for group in reference.backward ? reference.groups : reference.groups.reversed() where slots[2 * group] >= 0 {
            try budget.spend(slots[2 * group + 1] - slots[2 * group] + 1)
            guard let next = matchCapture(group, reference, position) else { return nil }
            position = next
        }
        return position
    }

    private func matchCapture(_ group: Int, _ reference: Backreference, _ offset: Int) -> Int? {
        let start = slots[2 * group]
        let length = slots[2 * group + 1] - start
        let from = reference.backward ? offset - length : offset
        guard from >= 0, from + length <= input.text.count else { return nil }
        let text = input.text
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
        if body.pure, pureLooks != nil { return try (pureLooks?.evaluate(index, at: offset, budget: &budget) == true) != body.look.negated }
        try budget.spend(2 * slots.count)
        let snapshot = slots
        if !body.look.negated {
            saved.append(snapshot)
            stack.append(.captures(saved.count - 1))
        }
        let base = stack.count
        let savedBase = saved.count
        let found = try run(body.start, offset)
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

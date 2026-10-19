extension LazyDFA {
    struct Closure {
        var consumers: [Int32] = []
        var looks: [Int] = []
        var accepts = false
    }

    mutating func closure(_ pcs: [Int32], before: UnitContext, after: UnitContext, _ oracle: (Int) -> Bool) -> Closure {
        generation &+= 1
        if generation == 0 {
            seen = Array(repeating: 0, count: seen.count)
            generation = 1
        }
        var result = Closure()
        var stack = Array(pcs.reversed())
        while let pc = stack.popLast() {
            let index = Int(pc)
            guard seen[index] != generation else { continue }
            seen[index] = generation
            switch program.instructions[index] {
            case .unit, .set: result.consumers.append(pc)
            case .split(let first, let second): stack += [Int32(second), Int32(first)]
            case .jump(let target): stack.append(Int32(target))
            case .assertion(let assertion): if assertion.holds(before: before, after: after) { stack.append(pc + 1) }
            case .look(let look):
                result.looks.append(look)
                if oracle(look) != program.looks[look].look.negated { stack.append(pc + 1) }
            case .match: result.accepts = true
            default: stack.append(pc + 1)
            }
        }
        return result
    }
}

extension RegexCompiler {
    mutating func emitQuantified(_ body: RegexNode, _ quantifier: Quantifier, backward: Bool) {
        guard quantifier.max != 0 else { return }
        if !automaton, let set = singleSet(body) {
            code.append(
                .repeatSet(
                    RepeatSet(set: set, min: quantifier.min, max: quantifier.max, greedy: quantifier.greedy, backward: backward)))
            return
        }
        let mark = body.canBeEmpty && !automaton ? newRegister() : nil
        var count = 0
        while count < quantifier.min, !oversized {
            emitIteration(body, mark: nil, backward: backward)
            count += 1
        }
        if let max = quantifier.max {
            emitOptional(body, count: max - quantifier.min, greedy: quantifier.greedy, mark: mark, backward: backward)
        } else {
            emitStar(body, greedy: quantifier.greedy, mark: mark, backward: backward)
        }
    }

    private mutating func singleSet(_ body: RegexNode) -> Int? {
        switch body {
        case .unit(let unit): intern(CharSet(unit: unit))
        case .set(let set): intern(set)
        default: nil
        }
    }

    private mutating func emitIteration(_ body: RegexNode, mark: Int?, backward: Bool) {
        if !automaton, let captures = body.captureRange { code.append(.state(.clear(captures))) }
        if let mark { code.append(.state(.mark(mark))) }
        emit(body, backward: backward)
        if let mark { code.append(.state(.progress(mark))) }
    }

    private mutating func emitStar(_ body: RegexNode, greedy: Bool, mark: Int?, backward: Bool) {
        let loop = code.count
        code.append(.succeed)
        emitIteration(body, mark: mark, backward: backward)
        code.append(.jump(loop))
        code[loop] = greedy ? .split(loop + 1, code.count) : .split(code.count, loop + 1)
        if inMain && dependentEnd > loop { dependentEnd = code.count }
    }

    private mutating func emitOptional(_ body: RegexNode, count: Int, greedy: Bool, mark: Int?, backward: Bool) {
        var splits: [Int] = []
        while splits.count < count, !oversized {
            splits.append(code.count)
            code.append(.succeed)
            emitIteration(body, mark: mark, backward: backward)
        }
        let end = code.count
        for split in splits { code[split] = greedy ? .split(split + 1, end) : .split(end, split + 1) }
    }
}

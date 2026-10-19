extension RegexCompiler {
    mutating func emitQuantified(_ body: RegexNode, _ requested: Quantifier, backward: Bool) {
        guard requested.max != 0 else { return }
        let quantifier = clamp(requested, body)
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

    private mutating func clamp(_ quantifier: Quantifier, _ body: RegexNode) -> Quantifier {
        let length = body.minimumLength
        let usable = length == 0 ? maxStringLength + 1 : (maxStringLength + length - 1) / length
        let min = Swift.min(quantifier.min, usable + 1)
        let max = quantifier.max.map { Swift.max(Swift.min($0, usable), min) }
        if min != quantifier.min || max != quantifier.max { clamped = true }
        return Quantifier(min: min, max: max, greedy: quantifier.greedy)
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

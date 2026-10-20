struct CompiledPattern: Sendable {
    let program: RegexProgram
    let prefilter: Prefilter
    let plan: SearchPlan
    let automaton: AutomatonCache?
    let scanners: [AutomatonCache?]
    let oversized: Bool
    private let unanchored: Deferred<AutomatonCache>?
    private static let probeSize = 2048

    init(_ source: String) throws(RegexSyntaxError) {
        let parsed = try RegexParser.parse(source)
        let analysis = PatternAnalysis(parsed)
        prefilter = Prefilter(parsed.root)
        plan = SearchPlan(parsed.root, automaton: analysis.automaton, anchored: prefilter.anchored)
        program = RegexCompiler.compile(parsed, analysis: analysis, backward: plan.backward)
        oversized = program.size > RegexCompiler.instructionLimit
        guard !oversized else {
            automaton = nil
            scanners = []
            unanchored = nil
            return
        }
        automaton = program.automaton ? AutomatonCache(Self.main(program, plan, prefilter)) : nil
        unanchored = plan.backward ? Self.unanchored(program) : nil
        scanners = zip(program.scans, program.looks).map { scan, body in
            scan.map { AutomatonCache(LazyDFA($0, anchored: false, backward: !body.look.behind, scanning: true)) }
        }
    }

    private static func main(_ program: RegexProgram, _ plan: SearchPlan, _ prefilter: Prefilter) -> LazyDFA {
        plan.backward
            ? LazyDFA(program, anchored: true, backward: true) : LazyDFA(program, anchored: prefilter.anchored, first: prefilter.first)
    }

    private static func unanchored(_ program: RegexProgram) -> Deferred<AutomatonCache> {
        let pool = MemoryPool.current
        return Deferred {
            MemoryPool.$current.withValue(pool) { AutomatonCache(LazyDFA(program, anchored: false, backward: true)) }
        }
    }

    var bytes: Int { program.size * (MemoryLayout<Instruction>.stride + MemoryLayout<UInt32>.stride) }

    func test(_ text: String) -> Bool? {
        let units = codeUnits(text)
        guard prefilter.admits(units) else { return false }
        guard !oversized, units.count <= maxStringLength || !program.clamped else { return nil }
        let call = CallBudget.current
        let allowance = call?.remaining ?? Int.max
        guard allowance > 0 else { return nil }
        let context = MatchContext(units, scanners: scanners, allowance: allowance)
        defer { call?.charge(context.spent) }
        return match(units, context)
    }

    private func match(_ units: [UInt16], _ context: MatchContext) -> Bool? {
        guard let automaton else {
            context.limit(StepBudget.backtrackingLimit)
            var matcher = Backtracker(program, context)
            return try? matcher.search(prefilter)
        }
        context.limit(16 * (units.count + 64))
        if program.size >= Self.probeSize, let found = probe(units, context) { return found }
        context.limit(StepBudget.linear(units: units.count, instructions: program.size))
        guard plan.backward else { return try? automaton.matches(units, context: context) }
        return try? reverse(automaton, units, context)
    }

    private func probe(_ units: [UInt16], _ context: MatchContext) -> Bool? {
        var probe = Backtracker(program, context)
        guard plan.backward else { return try? probe.search(prefilter) }
        var end = plan.end(in: units, after: nil)
        do {
            while let current = end {
                if try probe.run(0, current) { return true }
                end = plan.end(in: units, after: current)
            }
        } catch {
            return nil
        }
        return false
    }

    private func reverse(_ automaton: AutomatonCache, _ units: [UInt16], _ context: MatchContext) throws(BudgetExceeded) -> Bool {
        var floor = 0
        var end = plan.end(in: units, after: nil)
        while let current = end {
            switch try automaton.reverse(units, from: current, floor: floor, context: context) {
            case .match: return true
            case .miss: floor = current
            case .undecided:
                guard let unanchored else { throw BudgetExceeded() }
                return try unanchored.value.reverse(units, from: units.count, floor: 0, context: context) == .match
            }
            end = plan.end(in: units, after: current)
        }
        return false
    }
}

private func codeUnits(_ text: String) -> [UInt16] {
    var text = text
    let ascii = text.withUTF8 { bytes in
        var wide = 0
        let units = [UInt16](unsafeUninitializedCapacity: bytes.count) { buffer, count in
            for index in bytes.indices {
                buffer[index] = UInt16(bytes[index])
                wide |= Int(bytes[index] & 0x80)
            }
            count = bytes.count
        }
        return wide == 0 ? units : nil
    }
    return ascii ?? Array(text.utf16)
}

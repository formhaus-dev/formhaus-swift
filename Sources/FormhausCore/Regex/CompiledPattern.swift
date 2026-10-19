import os

struct CompiledPattern: Sendable {
    let program: RegexProgram
    let prefilter: Prefilter
    let automaton: AutomatonCache?
    let scanners: [AutomatonCache?]
    let oversized: Bool
    private static let probeSize = 2048

    init(_ source: String) throws(RegexSyntaxError) {
        let parsed = try RegexParser.parse(source)
        program = RegexCompiler.compile(parsed)
        prefilter = Prefilter(parsed.root)
        oversized = program.size > RegexCompiler.instructionLimit
        guard !oversized else {
            automaton = nil
            scanners = []
            return
        }
        automaton = program.automaton ? AutomatonCache(LazyDFA(program, anchored: prefilter.anchored, first: prefilter.first)) : nil
        scanners = zip(program.scans, program.looks).map { scan, body in
            scan.map { AutomatonCache(LazyDFA($0, anchored: false, backward: !body.look.behind, scanning: true)) }
        }
    }

    var bytes: Int { program.size * (MemoryLayout<Instruction>.stride + MemoryLayout<UInt32>.stride) }

    func test(_ text: String) -> Bool? {
        let units = codeUnits(text)
        guard prefilter.admits(units) else { return false }
        guard !oversized, units.count <= maxStringLength || !program.clamped else { return nil }
        guard let automaton else {
            var matcher = Backtracker(program, MatchContext(units, scanners: scanners, budget: .backtracking))
            return try? matcher.search(prefilter)
        }
        let context = MatchContext(units, scanners: scanners, budget: StepBudget(limit: 16 * (units.count + 64)))
        if program.size >= Self.probeSize {
            var probe = Backtracker(program, context)
            if let found = try? probe.search(prefilter) { return found }
        }
        context.budget = .linear(units: units.count, instructions: program.size)
        return try? automaton.matches(units, context: context)
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

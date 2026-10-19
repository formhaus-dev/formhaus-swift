import os

struct CompiledPattern: Sendable {
    let program: RegexProgram
    let prefilter: Prefilter
    let automaton: AutomatonCache?
    let scanners: [AutomatonCache?]

    init(_ source: String) throws(RegexSyntaxError) {
        let parsed = try RegexParser.parse(source)
        program = RegexCompiler.compile(parsed)
        prefilter = Prefilter(parsed.root)
        automaton = program.automaton ? AutomatonCache(LazyDFA(program, anchored: prefilter.anchored)) : nil
        scanners = zip(program.scans, program.looks).map { scan, body in
            scan.map { AutomatonCache(LazyDFA($0, anchored: false, backward: !body.look.behind, scanning: true)) }
        }
    }

    func test(_ text: String) -> Bool? {
        let units = codeUnits(text)
        guard prefilter.admits(units) else { return false }
        let input = MatchInput(text: units)
        var looks = program.looks.isEmpty ? nil : LookOracle(program, scanners, input)
        if let automaton, program.looks.isEmpty || looks != nil {
            var local = automaton.snapshot()
            let known = local.keys.count
            let matched = local.matches(units, first: prefilter.first, looks: &looks)
            if local.keys.count > known { automaton.store(local) }
            return matched
        }
        var matcher = Backtracker(program, input)
        return try? matcher.search(prefilter)
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

final class AutomatonCache: Sendable {
    private let shared: OSAllocatedUnfairLock<LazyDFA>

    init(_ automaton: LazyDFA) {
        shared = OSAllocatedUnfairLock(initialState: automaton)
    }

    func snapshot() -> LazyDFA {
        shared.withLock { $0 }
    }

    func store(_ automaton: LazyDFA) {
        let replaced = shared.withLock { current -> LazyDFA? in
            guard automaton.keys.count > current.keys.count else { return nil }
            defer { current = automaton }
            return current
        }
        _ = replaced
    }
}

final class PatternCache: Sendable {
    private struct Entry {
        let pattern: CompiledPattern?
        var used: UInt64
    }

    private struct State {
        var entries: [String: Entry] = [:]
        var clock: UInt64 = 0
    }

    static let shared = PatternCache()
    static let limit = 256

    private let state = OSAllocatedUnfairLock(initialState: State())

    func pattern(_ source: String) -> CompiledPattern? {
        let cached = state.withLock { state -> CompiledPattern?? in
            guard let entry = state.entries[source] else { return nil }
            state.clock += 1
            state.entries[source]?.used = state.clock
            return .some(entry.pattern)
        }
        if let cached { return cached }
        let compiled = try? CompiledPattern(source)
        state.withLock { state in
            if state.entries.count >= Self.limit, let oldest = state.entries.min(by: { $0.value.used < $1.value.used })?.key {
                state.entries[oldest] = nil
            }
            state.clock += 1
            state.entries[source] = Entry(pattern: compiled, used: state.clock)
        }
        return compiled
    }
}

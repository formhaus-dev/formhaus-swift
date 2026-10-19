import os

struct CompiledPattern: Sendable {
    let program: RegexProgram
    let prefilter: Prefilter
    let automaton: AutomatonCache?
    let scanners: [AutomatonCache?]
    let oversized: Bool
    private let size: Int

    init(_ source: String) throws(RegexSyntaxError) {
        let parsed = try RegexParser.parse(source)
        program = RegexCompiler.compile(parsed)
        prefilter = Prefilter(parsed.root)
        automaton = program.automaton ? AutomatonCache(LazyDFA(program, anchored: prefilter.anchored)) : nil
        scanners = zip(program.scans, program.looks).map { scan, body in
            scan.map { AutomatonCache(LazyDFA($0, anchored: false, backward: !body.look.behind, scanning: true)) }
        }
        size = program.instructions.count + program.scans.reduce(0) { $0 + ($1?.instructions.count ?? 0) }
        oversized = size > RegexCompiler.instructionLimit
    }

    func test(_ text: String) -> Bool? {
        guard !oversized else { return nil }
        let units = codeUnits(text)
        guard prefilter.admits(units) else { return false }
        guard let automaton else {
            var matcher = Backtracker(program, MatchContext(units, scanners: scanners, budget: .backtracking))
            return try? matcher.search(prefilter)
        }
        let context = MatchContext(units, scanners: scanners, budget: .linear(units: units.count, instructions: size))
        var local = automaton.snapshot()
        let revision = local.revision
        let matched = try? local.matches(units, first: prefilter.first, context: context)
        if local.revision != revision { automaton.store(local) }
        return matched
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
        var automaton = automaton
        shared.withLockUnchecked { current in
            if automaton.revision > current.revision { swap(&current, &automaton) }
        }
    }
}

final class PatternCache: Sendable {
    static let shared = PatternCache()
    static let limit = 256

    private let state = OSAllocatedUnfairLock(initialState: RecentPatterns())

    func pattern(_ source: String) -> CompiledPattern? {
        if let cached = state.withLock({ $0.lookup(source) }) { return cached }
        let compiled = try? CompiledPattern(source)
        state.withLock { $0.insert(source, compiled, limit: Self.limit) }
        return compiled
    }
}

private struct RecentPatterns {
    private struct Node {
        var key: String
        var pattern: CompiledPattern?
        var newer = -1
        var older = -1
    }

    private var nodes: [Node] = []
    private var positions: [String: Int] = [:]
    private var newest = -1
    private var oldest = -1

    mutating func lookup(_ key: String) -> CompiledPattern?? {
        guard let position = positions[key] else { return nil }
        promote(position)
        return .some(nodes[position].pattern)
    }

    mutating func insert(_ key: String, _ pattern: CompiledPattern?, limit: Int) {
        if let position = positions[key] {
            nodes[position].pattern = pattern
            promote(position)
            return
        }
        let position: Int
        if nodes.count < limit {
            position = nodes.count
            nodes.append(Node(key: key, pattern: pattern))
        } else {
            position = oldest
            unlink(position)
            positions[nodes[position].key] = nil
            nodes[position] = Node(key: key, pattern: pattern)
        }
        positions[key] = position
        link(position)
    }

    private mutating func promote(_ position: Int) {
        guard position != newest else { return }
        unlink(position)
        link(position)
    }

    private mutating func unlink(_ position: Int) {
        let node = nodes[position]
        if node.newer >= 0 { nodes[node.newer].older = node.older } else { newest = node.older }
        if node.older >= 0 { nodes[node.older].newer = node.newer } else { oldest = node.newer }
    }

    private mutating func link(_ position: Int) {
        nodes[position].newer = -1
        nodes[position].older = newest
        if newest >= 0 { nodes[newest].newer = position }
        newest = position
        if oldest < 0 { oldest = position }
    }
}

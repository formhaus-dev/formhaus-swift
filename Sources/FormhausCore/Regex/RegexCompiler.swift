struct RegexCompiler {
    private struct PendingLook {
        let body: RegexNode
        let index: Int
        let look: Look
        let pure: Bool
    }

    static let expansionLimit: Double = 20000

    var code: [Instruction] = []
    var registers: Int
    var dependentEnd = 0
    var inMain = true
    var inPureLook = false
    let expand: Bool
    let automaton: Bool
    private let referenced: Set<Int>
    private var sets: [CharSet] = []
    private var setIndex: [CharSet: Int] = [:]
    private var looks: [LookBody] = []
    private var references: [Backreference] = []
    private var pending: [PendingLook] = []

    private var scans: [RegexProgram?] = []
    private let captureCount: Int

    private init(_ parsed: ParsedPattern) {
        captureCount = parsed.captureCount
        registers = parsed.captureCount + 1
        let expand = parsed.root.expandedSize <= Self.expansionLimit
        var referenced: Set<Int> = []
        _ = parsed.root.contains { node in
            if case .backreference(let groups, _) = node { referenced.formUnion(groups) }
            return false
        }
        self.expand = expand
        self.referenced = referenced
        automaton = referenced.isEmpty && (expand || !parsed.root.contains(where: \.isCounted))
    }

    static func compile(_ parsed: ParsedPattern, backward: Bool = false) -> RegexProgram {
        var compiler = RegexCompiler(parsed)
        compiler.emit(parsed.root, backward: backward)
        let mainEnd = compiler.code.count
        compiler.code.append(.match)
        compiler.inMain = false
        compiler.emitLooks()
        return RegexProgram(
            instructions: compiler.code, sets: compiler.sets, looks: compiler.looks, scans: compiler.scans, references: compiler.references,
            captureCount: parsed.captureCount,
            registerCount: compiler.registers, mainEnd: mainEnd, memoFrom: compiler.dependentEnd, automaton: compiler.automaton)
    }

    mutating func newRegister() -> Int {
        registers += 1
        return registers - 1
    }

    mutating func emit(_ node: RegexNode, backward: Bool) {
        switch node {
        case .unit(let unit): code.append(.unit(unit, backward: backward))
        case .set(let set): code.append(.set(intern(set), backward: backward))
        case .sequence(let nodes):
            for child in backward ? nodes.reversed() : nodes { emit(child, backward: backward) }
        case .alternation(let branches): emitAlternation(branches, backward: backward)
        case .group(let body, let capture):
            if let capture { code.append(.groupStart(capture)) }
            emit(body, backward: backward)
            if let capture { code.append(.groupEnd(capture)) }
        case .quantified(let body, let quantifier): emitQuantified(body, quantifier, backward: backward)
        case .assertion(let assertion): code.append(.assertion(assertion))
        case .look(let body, let look): emitLook(body, look)
        case .backreference(let groups, let ignoreCase):
            references.append(Backreference(groups: groups, backward: backward, ignoreCase: ignoreCase))
            code.append(.backreference(references.count - 1))
            markDependent()
        }
    }

    mutating func markDependent() {
        if inMain { dependentEnd = code.count }
    }

    mutating func intern(_ set: CharSet) -> Int {
        if let index = setIndex[set] { return index }
        sets.append(set)
        setIndex[set] = sets.count - 1
        return sets.count - 1
    }

    private mutating func emitAlternation(_ branches: [RegexNode], backward: Bool) {
        var exits: [Int] = []
        for branch in branches.dropLast() {
            let split = code.count
            code.append(.succeed)
            emit(branch, backward: backward)
            exits.append(code.count)
            code.append(.succeed)
            code[split] = .split(split + 1, code.count)
        }
        if let last = branches.last { emit(last, backward: backward) }
        for exit in exits { code[exit] = .jump(code.count) }
    }

    private mutating func emitLook(_ body: RegexNode, _ look: Look) {
        let captures = body.captureRange
        let pure = !body.contains(where: isImpure) && !referenced.contains { captures?.contains($0) == true }
        pending.append(PendingLook(body: body, index: looks.count, look: look, pure: pure))
        let leaf = automaton && !body.contains { if case .look = $0 { true } else { false } }
        scans.append(leaf ? Self.compile(ParsedPattern(root: body, captureCount: captureCount), backward: !look.behind) : nil)
        looks.append(LookBody(start: 0, end: 0, look: look, pure: pure))
        code.append(.look(looks.count - 1))
        if !pure { markDependent() }
    }

    private func isImpure(_ node: RegexNode) -> Bool {
        if case .backreference = node { return true }
        return !expand && node.isCounted
    }

    private mutating func emitLooks() {
        var next = 0
        while next < pending.count {
            let item = pending[next]
            let start = code.count
            inPureLook = item.pure
            emit(item.body, backward: item.look.behind)
            looks[item.index] = LookBody(start: start, end: code.count, look: item.look, pure: item.pure)
            code.append(.succeed)
            next += 1
        }
    }
}

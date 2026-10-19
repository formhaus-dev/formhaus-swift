struct PatternAnalysis {
    struct LookInfo {
        let body: RegexNode
        let look: Look
        let pure: Bool
    }

    let captureCount: Int
    let expand: Bool
    let automaton: Bool
    let looks: [LookInfo]

    init(_ parsed: ParsedPattern) {
        captureCount = parsed.captureCount
        let expand = parsed.root.expandedSize <= RegexCompiler.expansionLimit
        var referenced: Set<Int> = []
        var bodies: [(RegexNode, Look)] = []
        _ = parsed.root.contains { node in
            if case .backreference(let groups, _) = node { referenced.formUnion(groups) }
            if case .look(let body, let look) = node { bodies.append((body, look)) }
            return false
        }
        self.expand = expand
        automaton = referenced.isEmpty && (expand || !parsed.root.contains(where: \.isCounted))
        looks = bodies.map { body, look in
            let captures = body.captureRange
            let impure = body.contains { node in
                if case .backreference = node { return true }
                return !expand && node.isCounted
            }
            return LookInfo(body: body, look: look, pure: !impure && !referenced.contains { captures?.contains($0) == true })
        }
    }
}

struct RegexCompiler {
    static let expansionLimit: Double = 20000
    static let instructionLimit = 32768

    var code: [Instruction] = []
    var registers: Int
    var dependentEnd = 0
    var inMain = true
    let analysis: PatternAnalysis
    let automaton: Bool
    private var sets: [CharSet] = []
    private var setIndex: [CharSet: Int] = [:]
    private var references: [Backreference] = []
    private var inline: [Int?]
    private var pending: [Int] = []
    private var queued: Set<Int> = []

    private init(_ analysis: PatternAnalysis, automaton: Bool) {
        self.analysis = analysis
        self.automaton = automaton
        registers = analysis.captureCount + 1
        inline = Array(repeating: nil, count: analysis.looks.count)
    }

    var expand: Bool { analysis.expand }

    static func compile(_ parsed: ParsedPattern) -> RegexProgram {
        let analysis = PatternAnalysis(parsed)
        var compiler = RegexCompiler(analysis, automaton: analysis.automaton)
        compiler.emit(parsed.root, backward: false)
        let mainEnd = compiler.code.count
        compiler.code.append(.match)
        compiler.inMain = false
        compiler.emitInlineLooks()
        let scans = analysis.looks.map { info in info.pure ? scanner(info, analysis) : nil }
        return compiler.program(mainEnd: mainEnd, scans: scans)
    }

    private static func scanner(_ info: PatternAnalysis.LookInfo, _ analysis: PatternAnalysis) -> RegexProgram {
        var compiler = RegexCompiler(analysis, automaton: true)
        compiler.inMain = false
        compiler.emit(info.body, backward: !info.look.behind)
        let end = compiler.code.count
        compiler.code.append(.match)
        return compiler.program(mainEnd: end, scans: [])
    }

    private func program(mainEnd: Int, scans: [RegexProgram?]) -> RegexProgram {
        RegexProgram(
            instructions: code, sets: sets, looks: analysis.looks.map { LookBody(look: $0.look, start: inline[$0.look.index]) },
            scans: scans, references: references, captureCount: analysis.captureCount, registerCount: registers,
            mainEnd: mainEnd, memoFrom: dependentEnd, automaton: automaton)
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
        case .look(_, let look): emitLook(look)
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

    private mutating func emitLook(_ look: Look) {
        code.append(.look(look.index))
        guard !analysis.looks[look.index].pure else { return }
        if queued.insert(look.index).inserted { pending.append(look.index) }
        markDependent()
    }

    private mutating func emitInlineLooks() {
        var next = 0
        while next < pending.count {
            let info = analysis.looks[pending[next]]
            inline[info.look.index] = code.count
            emit(info.body, backward: info.look.behind)
            code.append(.succeed)
            next += 1
        }
    }
}

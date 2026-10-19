struct LazyDFA: Sendable {
    struct Key: Hashable, Sendable {
        let pcs: [Int32]
        let context: UnitContext
    }

    struct Move {
        let target: Int32
        let accepts: Bool
    }

    static let unknown: Int32 = -1
    static let accept: Int32 = -2
    static let dead: Int32 = -3
    static let volatile: Int32 = -4
    private static let stateLimit = 4096
    private static let tableLimit = 1 << 21

    let program: RegexProgram
    let classes: UnitClasses
    let anchored: Bool
    let backward: Bool
    let scanning: Bool
    let width: Int
    var keys: [Key] = []
    var idle: [Bool] = []
    var lookup: [Key: Int32] = [:]
    var table: [Int32] = []
    var accepting: [Bool] = []
    var seen: [UInt32]
    var generation: UInt32 = 0

    init(_ program: RegexProgram, anchored: Bool, backward: Bool = false, scanning: Bool = false) {
        self.program = program
        classes = UnitClasses(program)
        self.anchored = anchored
        self.backward = backward
        self.scanning = scanning
        width = classes.count + 1
        seen = Array(repeating: 0, count: program.instructions.count)
        _ = intern(Key(pcs: [0], context: .edge))
    }

    mutating func matches(_ text: [UInt16], first: CharSet?, looks: inout LookOracle?) -> Bool {
        var state: Int32 = 0
        var position = 0
        while position < text.count {
            fastForward(text, &state, &position, skipping: first != nil && !anchored)
            guard position < text.count else { break }
            if let first, idle[Int(state)] {
                guard let next = text[position...].firstIndex(where: first.contains) else { return false }
                if next != position {
                    position = next
                    state = intern(Key(pcs: [0], context: UnitContext(text[next - 1])))
                }
            }
            let move = step(state, text[position], position, &looks)
            if move.target < 0 { return move.accepts }
            state = move.target
            position += 1
        }
        return step(state, nil, position, &looks).accepts
    }

    private func fastForward(_ text: [UInt16], _ state: inout Int32, _ position: inout Int, skipping: Bool) {
        table.withUnsafeBufferPointer { table in
            text.withUnsafeBufferPointer { text in
                while position < text.count, !skipping || !idle[Int(state)] {
                    let next = table[Int(state) * width + classes.index(of: text[position])]
                    guard next >= 0 else { return }
                    state = next
                    position += 1
                }
            }
        }
    }

    mutating func acceptance(_ text: [UInt16]) -> [Bool] {
        var accepted = Array(repeating: false, count: text.count + 1)
        var state: Int32 = 0
        var none: LookOracle?
        for offset in 0...text.count {
            let position = backward ? text.count - offset : offset
            let unit = backward ? (position > 0 ? text[position - 1] : nil) : (position < text.count ? text[position] : nil)
            let move = step(state, unit, position, &none)
            accepted[position] = move.accepts
            state = move.target
        }
        return accepted
    }

    private func column(_ unit: UInt16?) -> Int {
        unit.map(classes.index) ?? classes.count
    }

    private mutating func step(_ state: Int32, _ unit: UInt16?, _ position: Int, _ looks: inout LookOracle?) -> Move {
        let slot = Int(state) * width + column(unit)
        let target = table[slot]
        guard target == Self.unknown || target == Self.volatile else { return Move(target: target, accepts: accepting[slot]) }
        if keys.count >= Self.stateLimit || table.count >= Self.tableLimit {
            let key = keys[Int(state)]
            reset()
            return step(intern(key), unit, position, &looks)
        }
        return transition(state, unit) { looks?.evaluate($0, at: position) ?? false }
    }

    private mutating func reset() {
        keys.removeAll(keepingCapacity: true)
        idle.removeAll(keepingCapacity: true)
        lookup.removeAll(keepingCapacity: true)
        table.removeAll(keepingCapacity: true)
        accepting.removeAll(keepingCapacity: true)
    }

    mutating func intern(_ key: Key) -> Int32 {
        if let state = lookup[key] { return state }
        let state = Int32(keys.count)
        keys.append(key)
        idle.append(!anchored && key.pcs == [0])
        lookup[key] = state
        table.append(contentsOf: repeatElement(Self.unknown, count: width))
        accepting.append(contentsOf: repeatElement(false, count: width))
        return state
    }

    private mutating func transition(_ state: Int32, _ unit: UInt16?, _ oracle: (Int) -> Bool) -> Move {
        let key = keys[Int(state)]
        let context = unit.map(UnitContext.init) ?? .edge
        let reached =
            backward
            ? closure(key.pcs, before: context, after: key.context, oracle)
            : closure(key.pcs, before: key.context, after: context, oracle)
        var target = Self.accept
        if !reached.accepts || scanning {
            var next = unit.map { unit in reached.consumers.filter { consumes(Int($0), unit) }.map { $0 + 1 } } ?? []
            if !anchored && unit != nil { next.append(0) }
            next.sort()
            target = next.isEmpty ? Self.dead : intern(Key(pcs: next, context: context))
        }
        let slot = Int(state) * width + column(unit)
        let stored = reached.looks.isEmpty ? target : Self.volatile
        if table[slot] != stored { table[slot] = stored }
        if reached.accepts != accepting[slot] { accepting[slot] = reached.accepts }
        return Move(target: target, accepts: reached.accepts)
    }

    private func consumes(_ pc: Int, _ unit: UInt16) -> Bool {
        switch program.instructions[pc] {
        case .unit(let expected, _): expected == unit
        case .set(let index, _): program.sets[index].contains(unit)
        default: false
        }
    }
}

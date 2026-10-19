struct LazyDFA: Sendable {
    struct Key: Hashable, Sendable {
        let pcs: [Int32]
        let context: UnitContext
    }

    enum Next {
        case state(Int32)
        case threads(Key)
        case stop
    }

    struct Move {
        let accepts: Bool
        let next: Next
    }

    static let start = Key(pcs: [0], context: .edge)
    private static let unknown: Int32 = -1
    private static let stop: Int32 = -2
    private static let volatile: Int32 = -3

    let classes: UnitClasses
    let width: Int
    private(set) var stepper: ThreadStep
    private var keys: [Key] = []
    private var idle: [Bool] = []
    private var lookup: [Key: Int32] = [:]
    private var table: [Int32] = []
    private var accepting: [Bool] = []
    private var memory = AutomatonMemory()
    private var resets = 0

    init(_ program: RegexProgram, anchored: Bool, backward: Bool = false, scanning: Bool = false) {
        classes = UnitClasses(program)
        width = classes.count + 1
        stepper = ThreadStep(program, anchored: anchored, backward: backward, scanning: scanning)
        append(Self.start)
    }

    var bytes: Int { memory.used }

    mutating func release() {
        memory.release()
    }

    mutating func matches(_ text: [UInt16], first: CharSet?, context: MatchContext) throws(BudgetExceeded) -> Bool {
        var state: Int32 = 0
        var position = 0
        var overflow = Overflow()
        let skipping = first != nil && !stepper.anchored
        while position < text.count {
            fastForward(text, &state, &position, skipping: skipping)
            guard position < text.count else { break }
            if let first, idle[Int(state)] {
                guard let next = text[position...].firstIndex(where: first.contains) else { return false }
                if next != position {
                    position = next
                    let key = Key(pcs: [0], context: UnitContext(text[next - 1]))
                    guard let restart = intern(key, &overflow) else { return try stepper.matches(key, text, from: position, context) }
                    state = restart
                }
            }
            let move = try step(state, text[position], position, context, &overflow)
            if move.accepts { return true }
            switch move.next {
            case .state(let next): state = next
            case .threads(let key): return try stepper.matches(key, text, from: position + 1, context)
            case .stop: return false
            }
            position += 1
        }
        return try step(state, nil, position, context, &overflow).accepts
    }

    mutating func acceptance(_ text: [UInt16], context: MatchContext) throws(BudgetExceeded) -> [Bool] {
        var accepted = Array(repeating: false, count: text.count + 1)
        var state: Int32 = 0
        var overflow = Overflow()
        for offset in 0...text.count {
            let position = stepper.backward ? text.count - offset : offset
            let move = try step(state, text.nextUnit(from: position, backward: stepper.backward), position, context, &overflow)
            accepted[position] = move.accepts
            switch move.next {
            case .state(let next): state = next
            case .threads(let key):
                try stepper.acceptance(key, text, from: offset + 1, into: &accepted, context)
                return accepted
            case .stop: return accepted
            }
        }
        return accepted
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

    private func column(_ unit: UInt16?) -> Int {
        unit.map(classes.index) ?? classes.count
    }

    private mutating func step(
        _ state: Int32, _ unit: UInt16?, _ position: Int, _ context: MatchContext, _ overflow: inout Overflow
    ) throws(BudgetExceeded) -> Move {
        let slot = Int(state) * width + column(unit)
        let target = table[slot]
        if target >= 0 { return Move(accepts: accepting[slot], next: .state(target)) }
        if target == Self.stop { return Move(accepts: accepting[slot], next: .stop) }
        let key = keys[Int(state)]
        let advance = try stepper.advance(key.pcs, key.context, unit, at: position, context)
        guard let unit, !advance.next.isEmpty, !advance.accepts || stepper.scanning else {
            record(slot, Self.stop, advance)
            return Move(accepts: advance.accepts, next: .stop)
        }
        let next = Key(pcs: advance.next.sorted(), context: UnitContext(unit))
        let generation = resets
        guard let id = intern(next, &overflow) else { return Move(accepts: advance.accepts, next: .threads(next)) }
        if generation == resets { record(slot, id, advance) }
        return Move(accepts: advance.accepts, next: .state(id))
    }

    private mutating func record(_ slot: Int, _ target: Int32, _ advance: ThreadStep.Advance) {
        table[slot] = advance.volatile ? Self.volatile : target
        accepting[slot] = advance.accepts
    }

    private mutating func intern(_ key: Key, _ overflow: inout Overflow) -> Int32? {
        if let state = lookup[key] { return state }
        let cost = 4 * key.pcs.count + 5 * width + 96
        if memory.reserve(cost) { return append(key) }
        guard overflow.mayReset else { return nil }
        overflow.mayReset = false
        reset()
        return memory.reserve(cost) ? append(key) : nil
    }

    private mutating func reset() {
        keys = []
        idle = []
        lookup = [:]
        table = []
        accepting = []
        memory.release()
        resets += 1
        append(Self.start)
    }

    @discardableResult
    private mutating func append(_ key: Key) -> Int32 {
        let state = Int32(keys.count)
        keys.append(key)
        idle.append(!stepper.anchored && key.pcs == [0])
        lookup[key] = state
        table.append(contentsOf: repeatElement(Self.unknown, count: width))
        accepting.append(contentsOf: repeatElement(false, count: width))
        return state
    }
}

private struct Overflow {
    var mayReset = true
}

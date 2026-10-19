import os

struct AutomatonMemory: Sendable {
    static let patternLimit = 1 << 20
    static let globalLimit = 32 << 20
    private static let chunk = 64 << 10
    private static let pool = OSAllocatedUnfairLock(initialState: 0)

    private(set) var used = 0
    private var reserved = 0

    static var reservedTotal: Int { pool.withLock { $0 } }

    mutating func reserve(_ bytes: Int) -> Bool {
        guard used + bytes <= Self.patternLimit else { return false }
        if used + bytes > reserved {
            let grant = min(max(Self.chunk, used + bytes - reserved), Self.patternLimit - reserved)
            let granted = Self.pool.withLock { total in
                guard total + grant <= Self.globalLimit else { return false }
                total += grant
                return true
            }
            guard granted else { return false }
            reserved += grant
        }
        used += bytes
        return true
    }

    mutating func release() {
        let returned = reserved
        Self.pool.withLock { $0 -= returned }
        used = 0
        reserved = 0
    }
}

final class AutomatonCache: Sendable {
    private let shared: OSAllocatedUnfairLock<LazyDFA>
    private let fallback: ThreadStep

    init(_ automaton: LazyDFA) {
        fallback = automaton.stepper
        shared = OSAllocatedUnfairLock(initialState: automaton)
    }

    deinit {
        shared.withLockUnchecked { $0.release() }
    }

    func matches(_ text: [UInt16], first: CharSet?, context: MatchContext) throws(BudgetExceeded) -> Bool {
        let outcome = shared.withLockIfAvailableUnchecked { automaton in
            Result { () throws(BudgetExceeded) in try automaton.matches(text, first: first, context: context) }
        }
        if let outcome { return try outcome.get() }
        var stepper = fallback
        return try stepper.matches(LazyDFA.start, text, from: 0, context)
    }

    func acceptance(_ text: [UInt16], context: MatchContext) throws(BudgetExceeded) -> [Bool] {
        let outcome = shared.withLockIfAvailableUnchecked { automaton in
            Result { () throws(BudgetExceeded) in try automaton.acceptance(text, context: context) }
        }
        if let outcome { return try outcome.get() }
        var stepper = fallback
        var accepted = Array(repeating: false, count: text.count + 1)
        try stepper.acceptance(LazyDFA.start, text, from: 0, into: &accepted, context)
        return accepted
    }

    func inspect<Value>(_ body: (LazyDFA) -> Value) -> Value {
        shared.withLockUnchecked { body($0) }
    }
}

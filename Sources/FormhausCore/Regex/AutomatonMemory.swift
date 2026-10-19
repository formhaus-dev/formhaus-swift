import os

struct AutomatonMemory: Sendable {
    static let patternLimit = 1 << 20
    static let globalLimit = 32 << 20
    private static let chunk = 4 << 10
    private static let pool = OSAllocatedUnfairLock(initialState: 0)

    private(set) var used = 0
    private var reserved = 0

    static var reservedTotal: Int { pool.withLock { $0 } }

    mutating func reserve(_ bytes: Int) -> Bool {
        guard used + bytes <= Self.patternLimit else { return false }
        if used + bytes > reserved {
            let grant = min(max(Self.chunk, used + bytes - reserved), Self.patternLimit - reserved)
            guard Self.take(grant) || AutomatonShard.reclaim() && Self.take(grant) else { return false }
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

    private static func take(_ bytes: Int) -> Bool {
        pool.withLock { total in
            guard total + bytes <= globalLimit else { return false }
            total += bytes
            return true
        }
    }
}

final class AutomatonShard: @unchecked Sendable {
    private struct Entry {
        weak var shard: AutomatonShard?
    }

    private static let registry = OSAllocatedUnfairLock(uncheckedState: [ObjectIdentifier: Entry]())

    private let template: LazyDFA
    private let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
    @exclusivity(unchecked) private var automaton: LazyDFA
    @exclusivity(unchecked) private var recent = false

    init(_ template: LazyDFA) {
        self.template = template
        automaton = template
        lock.initialize(to: os_unfair_lock())
        let entry = Entry(shard: self)
        Self.registry.withLockUnchecked { $0[ObjectIdentifier(self)] = entry }
    }

    deinit {
        let key = ObjectIdentifier(self)
        Self.registry.withLockUnchecked { _ = $0.removeValue(forKey: key) }
        automaton.release()
        lock.deallocate()
    }

    var bytes: Int {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return automaton.bytes
    }

    func run<Value>(_ body: (inout LazyDFA) throws(BudgetExceeded) -> Value) -> Result<Value, BudgetExceeded>? {
        guard os_unfair_lock_trylock(lock) else { return nil }
        defer { os_unfair_lock_unlock(lock) }
        recent = true
        return Result { () throws(BudgetExceeded) in try body(&automaton) }
    }

    static func reclaim() -> Bool {
        let shards = registry.withLockUnchecked { $0.values.compactMap(\.shard) }
        return shards.contains { $0.evict(sparingRecent: true) } || shards.contains { $0.evict(sparingRecent: false) }
    }

    private func evict(sparingRecent: Bool) -> Bool {
        guard os_unfair_lock_trylock(lock) else { return false }
        defer { os_unfair_lock_unlock(lock) }
        guard automaton.bytes > 0 else { return false }
        if sparingRecent && recent {
            recent = false
            return false
        }
        automaton.release()
        automaton = template
        return true
    }
}

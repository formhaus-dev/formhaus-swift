import os

final class MemoryPool: Sendable {
    struct Entry {
        weak var shard: AutomatonShard?
    }

    static let shared = MemoryPool()
    @TaskLocal static var current = shared

    let limit: Int
    private let total = OSAllocatedUnfairLock(initialState: 0)
    let registry = OSAllocatedUnfairLock(uncheckedState: [ObjectIdentifier: Entry]())

    init(limit: Int = AutomatonMemory.globalLimit) {
        self.limit = limit
    }

    var reserved: Int { total.withLock { $0 } }

    func take(_ bytes: Int) -> Bool {
        total.withLock { total in
            guard total + bytes <= limit else { return false }
            total += bytes
            return true
        }
    }

    func give(_ bytes: Int) {
        total.withLock { $0 -= bytes }
    }

    func reclaim() -> Bool {
        let shards = registry.withLockUnchecked { $0.values.compactMap(\.shard) }
        return shards.contains { $0.evict(sparingRecent: true) } || shards.contains { $0.evict(sparingRecent: false) }
    }
}

struct AutomatonMemory: Sendable {
    static let patternLimit = 1 << 20
    static let globalLimit = 32 << 20
    private static let chunk = 4 << 10

    let pool = MemoryPool.current
    private(set) var used = 0
    private var reserved = 0

    static var reservedTotal: Int { MemoryPool.current.reserved }

    mutating func reserve(_ bytes: Int) -> Bool {
        guard used + bytes <= Self.patternLimit else { return false }
        if used + bytes > reserved {
            let grant = min(max(Self.chunk, used + bytes - reserved), Self.patternLimit - reserved)
            guard pool.take(grant) || pool.reclaim() && pool.take(grant) else { return false }
            reserved += grant
        }
        used += bytes
        return true
    }

    mutating func release() {
        pool.give(reserved)
        used = 0
        reserved = 0
    }
}

final class AutomatonShard: @unchecked Sendable {
    private let template: LazyDFA
    private let pool: MemoryPool
    private let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
    @exclusivity(unchecked) private var automaton: LazyDFA
    @exclusivity(unchecked) private var recent = false

    init(_ template: LazyDFA) {
        self.template = template
        automaton = template
        pool = template.pool
        lock.initialize(to: os_unfair_lock())
        let entry = MemoryPool.Entry(shard: self)
        pool.registry.withLockUnchecked { $0[ObjectIdentifier(self)] = entry }
    }

    deinit {
        let key = ObjectIdentifier(self)
        pool.registry.withLockUnchecked { _ = $0.removeValue(forKey: key) }
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

    func evict(sparingRecent: Bool) -> Bool {
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

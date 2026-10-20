import Darwin
import os

final class AutomatonCache: Sendable {
    private static let shardCount = 8

    private let template: LazyDFA
    private let shards = OSAllocatedUnfairLock(uncheckedState: [AutomatonShard]())

    init(_ automaton: LazyDFA) {
        template = automaton
    }

    var bytes: Int { shards.withLockUnchecked { $0 }.reduce(0) { $0 + $1.bytes } }

    func matches(_ text: [UInt16], context: MatchContext) throws(BudgetExceeded) -> Bool {
        try run { automaton throws(BudgetExceeded) in
            try automaton.matches(text, context: context)
        } uncached: { stepper throws(BudgetExceeded) in
            try stepper.matches(LazyDFA.start, text, from: 0, context)
        }
    }

    func reverse(_ text: [UInt16], from end: Int, floor: Int, context: MatchContext) throws(BudgetExceeded) -> Verdict {
        try run { automaton throws(BudgetExceeded) in
            try automaton.reverse(text, from: end, floor: floor, context: context)
        } uncached: { stepper throws(BudgetExceeded) in
            try stepper.run(LazyDFA.entry(text, at: end), text, from: end, to: floor, context)
        }
    }

    func acceptance(_ text: [UInt16], context: MatchContext) throws(BudgetExceeded) -> [Bool] {
        try run { automaton throws(BudgetExceeded) in
            try automaton.acceptance(text, context: context)
        } uncached: { stepper throws(BudgetExceeded) in
            var accepted = Array(repeating: false, count: text.count + 1)
            try stepper.acceptance(LazyDFA.start, text, from: 0, into: &accepted, context)
            return accepted
        }
    }

    private func run<Value>(
        _ cached: (inout LazyDFA) throws(BudgetExceeded) -> Value, uncached: (inout ThreadStep) throws(BudgetExceeded) -> Value
    ) throws(BudgetExceeded) -> Value {
        let current = shards.withLockUnchecked { $0 }
        let start = Int(truncatingIfNeeded: (UInt64(pthread_mach_thread_np(pthread_self())) &* 0x9E37_79B9_7F4A_7C15) >> 61)
        for offset in current.indices {
            if let outcome = current[(start + offset) % current.count].run(cached) { return try outcome.get() }
        }
        if let added = addShard(), let outcome = added.run(cached) { return try outcome.get() }
        var stepper = template.stepper
        return try uncached(&stepper)
    }

    private func addShard() -> AutomatonShard? {
        shards.withLockUnchecked { shards in
            guard shards.count < Self.shardCount else { return nil }
            shards.append(AutomatonShard(template))
            return shards.last
        }
    }
}

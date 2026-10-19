import Darwin

final class AutomatonCache: Sendable {
    private static let shardCount = 8

    private let template: LazyDFA
    private let shards: [AutomatonShard]
    private let handles: [Unmanaged<AutomatonShard>]

    init(_ automaton: LazyDFA) {
        template = automaton
        shards = (0..<Self.shardCount).map { _ in AutomatonShard(automaton) }
        handles = shards.map { Unmanaged.passUnretained($0) }
    }

    var bytes: Int { shards.reduce(0) { $0 + $1.bytes } }

    func matches(_ text: [UInt16], context: MatchContext) throws(BudgetExceeded) -> Bool {
        try run { automaton throws(BudgetExceeded) in
            try automaton.matches(text, context: context)
        } uncached: { stepper throws(BudgetExceeded) in
            try stepper.matches(LazyDFA.start, text, from: 0, context)
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
        let start = Int(truncatingIfNeeded: (UInt64(pthread_mach_thread_np(pthread_self())) &* 0x9E37_79B9_7F4A_7C15) >> 61)
        for offset in 0..<handles.count {
            let outcome = handles[(start + offset) % handles.count]._withUnsafeGuaranteedRef { $0.run(cached) }
            if let outcome { return try outcome.get() }
        }
        var stepper = template.stepper
        return try uncached(&stepper)
    }
}

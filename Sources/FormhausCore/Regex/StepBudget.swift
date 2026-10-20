import os

struct BudgetExceeded: Error {}

struct StepBudget {
    @TaskLocal static var backtrackingLimit = 10_000_000

    private(set) var remaining: Int

    init(limit: Int) {
        remaining = limit
    }

    static func linear(units: Int, instructions: Int) -> Int {
        min(8 * (units + 2) * (instructions + 2), backtrackingLimit)
    }

    mutating func spend(_ steps: Int) throws(BudgetExceeded) {
        remaining -= steps
        guard remaining >= 0 else { throw BudgetExceeded() }
    }
}

final class CallBudget: Sendable {
    static let limit = 20_000_000
    @TaskLocal static var current: CallBudget?

    private let state: OSAllocatedUnfairLock<Int>

    init(limit: Int = CallBudget.limit) {
        state = OSAllocatedUnfairLock(initialState: limit)
    }

    var remaining: Int { state.withLock { $0 } }

    func charge(_ steps: Int) {
        state.withLock { $0 -= steps }
    }

    static func run<Value>(_ body: () -> Value) -> Value {
        current == nil ? $current.withValue(CallBudget(), operation: body) : body()
    }
}

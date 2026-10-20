struct BudgetExceeded: Error {}

struct StepBudget {
    @TaskLocal static var backtrackingLimit = 10_000_000

    static var backtracking: StepBudget { StepBudget(limit: backtrackingLimit) }

    private(set) var remaining: Int

    init(limit: Int) {
        remaining = limit
    }

    static func linear(units: Int, instructions: Int) -> StepBudget {
        StepBudget(limit: 8 * (units + 2) * (instructions + 2))
    }

    mutating func spend(_ steps: Int) throws(BudgetExceeded) {
        remaining -= steps
        guard remaining >= 0 else { throw BudgetExceeded() }
    }
}

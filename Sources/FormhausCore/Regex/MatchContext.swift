final class MatchContext {
    let text: [UInt16]
    @exclusivity(unchecked) private(set) var spent = 0
    @exclusivity(unchecked) private var budget = StepBudget(limit: 0)
    private let allowance: Int
    private let scanners: [AutomatonCache?]
    private var tables: [[Bool]?]

    init(_ text: [UInt16], scanners: [AutomatonCache?], allowance: Int) {
        self.text = text
        self.scanners = scanners
        self.allowance = allowance
        tables = Array(repeating: nil, count: scanners.count)
    }

    func limit(_ steps: Int) {
        budget = StepBudget(limit: min(steps, allowance - spent))
    }

    func spend(_ steps: Int) throws(BudgetExceeded) {
        spent += steps
        try budget.spend(steps)
    }

    func holds(_ index: Int, at position: Int) throws(BudgetExceeded) -> Bool {
        if let table = tables[index] { return table[position] }
        guard let scanner = scanners[index] else { preconditionFailure("look \(index) runs inline") }
        let table = try scanner.acceptance(text, context: self)
        tables[index] = table
        return table[position]
    }
}

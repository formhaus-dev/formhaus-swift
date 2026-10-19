final class MatchContext {
    let text: [UInt16]
    @exclusivity(unchecked) var budget: StepBudget
    private let scanners: [AutomatonCache?]
    private var tables: [[Bool]?]

    init(_ text: [UInt16], scanners: [AutomatonCache?], budget: StepBudget) {
        self.text = text
        self.scanners = scanners
        self.budget = budget
        tables = Array(repeating: nil, count: scanners.count)
    }

    func spend(_ steps: Int) throws(BudgetExceeded) {
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

struct Bitset {
    private var words: [UInt64]

    init(count: Int) {
        words = Array(repeating: 0, count: (count + 63) / 64)
    }

    mutating func insert(_ index: Int) -> Bool {
        let bit: UInt64 = 1 << UInt64(index & 63)
        let old = words[index >> 6]
        words[index >> 6] = old | bit
        return old & bit == 0
    }
}

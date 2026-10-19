struct LookOracle {
    private let scanners: [AutomatonCache?]
    private let text: [UInt16]
    private var tables: [[Bool]?]
    private var memo: MemoSearch?

    init?(_ program: RegexProgram, _ scanners: [AutomatonCache?], _ input: MatchInput) {
        self.scanners = scanners
        text = input.text
        tables = Array(repeating: nil, count: scanners.count)
        if scanners.contains(where: { $0 == nil }) {
            guard let memo = MemoSearch(program, input) else { return nil }
            self.memo = memo
        }
    }

    mutating func evaluate(_ index: Int, at position: Int) -> Bool {
        guard let scanner = scanners[index] else { return memo?.evaluate(index, at: position) ?? false }
        if let table = tables[index] { return table[position] }
        var local = scanner.snapshot()
        let known = local.keys.count
        let table = local.acceptance(text)
        if local.keys.count > known { scanner.store(local) }
        tables[index] = table
        return table[position]
    }
}

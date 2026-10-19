struct UnitClasses: Sendable {
    let starts: [UInt16]
    private let latin: [UInt16]

    init(_ program: RegexProgram) {
        var boundaries = [0]
        let ranges = program.sets.flatMap(\.ranges) + CharSet.word.ranges + CharSet.lineTerminator.ranges
        for range in ranges { boundaries += [Int(range.lowerBound), Int(range.upperBound) + 1] }
        for case .unit(let unit, _) in program.instructions { boundaries += [Int(unit), Int(unit) + 1] }
        boundaries.sort()
        var starts: [UInt16] = []
        for boundary in boundaries where boundary <= Int(UInt16.max) && starts.last.map({ Int($0) != boundary }) ?? true {
            starts.append(UInt16(boundary))
        }
        self.starts = starts
        var current = 0
        latin = (0..<256).map { unit in
            while current + 1 < starts.count, starts[current + 1] <= unit { current += 1 }
            return UInt16(current)
        }
    }

    var count: Int { starts.count }

    func index(of unit: UInt16) -> Int {
        if unit < 256 { return Int(latin[Int(unit)]) }
        var lower = 0
        var upper = starts.count
        while upper - lower > 1 {
            let middle = (lower + upper) / 2
            if starts[middle] <= unit {
                lower = middle
            } else {
                upper = middle
            }
        }
        return lower
    }
}

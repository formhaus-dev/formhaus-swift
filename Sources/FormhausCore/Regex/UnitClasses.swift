struct UnitClasses: Sendable {
    let starts: [UInt16]
    private let latin: [UInt16]

    private static let shared = (boundaries(of: [CharSet.word, CharSet.lineTerminator]) + [0]).sorted()

    init(_ program: RegexProgram) {
        var boundaries = Self.boundaries(of: program.sets)
        for case .unit(let unit, _) in program.instructions {
            boundaries.append(Int(unit))
            boundaries.append(Int(unit) + 1)
        }
        boundaries.sort()
        let starts = Self.merged(boundaries, Self.shared)
        self.starts = starts
        var latin = [UInt16](repeating: 0, count: 256)
        for (index, start) in starts.enumerated() where start < 256 {
            let end = index + 1 < starts.count ? min(Int(starts[index + 1]), 256) : 256
            for unit in Int(start)..<end { latin[unit] = UInt16(index) }
        }
        self.latin = latin
    }

    private static func merged(_ first: [Int], _ second: [Int]) -> [UInt16] {
        var starts: [UInt16] = []
        starts.reserveCapacity(first.count + second.count)
        var left = 0
        var right = 0
        while left < first.count || right < second.count {
            let next: Int
            if right == second.count || left < first.count && first[left] <= second[right] {
                next = first[left]
                left += 1
            } else {
                next = second[right]
                right += 1
            }
            if next <= Int(UInt16.max) && starts.last.map({ Int($0) != next }) ?? true { starts.append(UInt16(next)) }
        }
        return starts
    }

    private static func boundaries(of sets: [CharSet]) -> [Int] {
        var boundaries: [Int] = []
        for set in sets {
            for range in set.ranges {
                boundaries.append(Int(range.lowerBound))
                boundaries.append(Int(range.upperBound) + 1)
            }
        }
        return boundaries
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

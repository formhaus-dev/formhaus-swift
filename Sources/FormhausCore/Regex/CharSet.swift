struct CharSet: Sendable, Hashable {
    private(set) var ranges: [ClosedRange<UInt16>]
    private var low: UInt64 = 0
    private var high: UInt64 = 0

    init(_ ranges: [ClosedRange<UInt16>]) {
        self.ranges = Self.normalized(ranges)
        for range in self.ranges where range.lowerBound < 128 {
            for unit in range.lowerBound...min(range.upperBound, 127) {
                if unit < 64 { low |= 1 << unit } else { high |= 1 << (unit - 64) }
            }
        }
    }

    init(unit: UInt16) {
        self.init([unit...unit])
    }

    var singleUnit: UInt16? {
        guard ranges.count == 1, let range = ranges.first, range.lowerBound == range.upperBound else { return nil }
        return range.lowerBound
    }

    func contains(_ unit: UInt16) -> Bool {
        if unit < 64 { return low >> unit & 1 == 1 }
        if unit < 128 { return high >> (unit - 64) & 1 == 1 }
        var lower = 0
        var upper = ranges.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if ranges[middle].upperBound < unit {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower < ranges.count && ranges[lower].lowerBound <= unit
    }

    func union(_ other: CharSet) -> CharSet {
        CharSet(ranges + other.ranges)
    }

    var inverted: CharSet {
        var gaps: [ClosedRange<UInt16>] = []
        var next = 0
        for range in ranges {
            if Int(range.lowerBound) > next { gaps.append(UInt16(next)...range.lowerBound - 1) }
            next = Int(range.upperBound) + 1
        }
        if next <= Int(UInt16.max) { gaps.append(UInt16(next)...UInt16.max) }
        return CharSet(gaps)
    }

    private static func normalized(_ ranges: [ClosedRange<UInt16>]) -> [ClosedRange<UInt16>] {
        var merged: [ClosedRange<UInt16>] = []
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, Int(range.lowerBound) <= Int(last.upperBound) + 1 {
                merged[merged.count - 1] = last.lowerBound...max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }
}

extension CharSet {
    static let all = CharSet([0...UInt16.max])
    static let digit = CharSet([0x30...0x39])
    static let word = CharSet([0x30...0x39, 0x41...0x5A, 0x5F...0x5F, 0x61...0x7A])
    static let lineTerminator = CharSet([0x0A...0x0A, 0x0D...0x0D, 0x2028...0x2029])
    static let dot = lineTerminator.inverted
    static let notDigit = digit.inverted
    static let notWord = word.inverted
    static let space = CharSet([
        0x09...0x0D, 0x20...0x20, 0xA0...0xA0, 0x1680...0x1680, 0x2000...0x200A, 0x2028...0x2029, 0x202F...0x202F,
        0x205F...0x205F, 0x3000...0x3000, 0xFEFF...0xFEFF,
    ])
    static let notSpace = space.inverted
}

extension UInt16 {
    init(ascii scalar: Unicode.Scalar) {
        self = UInt16(scalar.value)
    }
}

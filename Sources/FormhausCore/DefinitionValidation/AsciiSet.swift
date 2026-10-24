struct AsciiSet: Equatable {
    private var low: UInt64 = 0
    private var high: UInt64 = 0

    static let all = AsciiSet(low: .max, high: .max)

    private init(low: UInt64, high: UInt64) {
        self.low = low
        self.high = high
    }

    init() {}

    init(_ unit: UInt16) {
        insert(unit)
    }

    var isEmpty: Bool { low == 0 && high == 0 }
    var count: Int { low.nonzeroBitCount + high.nonzeroBitCount }

    var single: UInt16? {
        guard count == 1 else { return nil }
        return low == 0 ? UInt16(64 + high.trailingZeroBitCount) : UInt16(low.trailingZeroBitCount)
    }

    func contains(_ unit: UInt16) -> Bool {
        guard unit < 128 else { return false }
        return unit < 64 ? low & (1 << unit) != 0 : high & (1 << (unit - 64)) != 0
    }

    mutating func insert(_ unit: UInt16) {
        guard unit < 128 else { return }
        if unit < 64 { low |= 1 << unit } else { high |= 1 << (unit - 64) }
    }

    func union(_ other: AsciiSet) -> AsciiSet {
        AsciiSet(low: low | other.low, high: high | other.high)
    }

    func intersection(_ other: AsciiSet) -> AsciiSet {
        AsciiSet(low: low & other.low, high: high & other.high)
    }

    func intersects(_ other: AsciiSet) -> Bool {
        !intersection(other).isEmpty
    }
}

struct AsciiCounts {
    private(set) var once = AsciiSet()
    private var twice = AsciiSet()

    mutating func add(_ set: AsciiSet) {
        twice = twice.union(once.intersection(set))
        once = once.union(set)
    }

    mutating func add(_ counts: AsciiCounts) {
        twice = twice.union(counts.twice).union(once.intersection(counts.once))
        once = once.union(counts.once)
    }

    func appearsOnce(_ unit: UInt16) -> Bool {
        once.contains(unit) && !twice.contains(unit)
    }
}

func asciiMatches(_ source: String) -> AsciiSet {
    guard let pattern = try? CompiledPattern(source) else { return AsciiSet() }
    var set = AsciiSet()
    for unit in UInt16(0)..<128 where pattern.test(String(decoding: [unit], as: UTF16.self)) == true { set.insert(unit) }
    return set
}

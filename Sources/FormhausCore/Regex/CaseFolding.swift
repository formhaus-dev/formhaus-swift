enum CaseFolding {
    static let canonical: [UInt16] = (0...UInt16.max).map(canonicalize)

    private static let orbits: [[UInt16]] = Dictionary(grouping: 0...UInt16.max) { canonical[Int($0)] }
        .values.filter { $0.count > 1 }.map { $0.sorted() }.sorted { $0[0] < $1[0] }

    static func fold(_ set: CharSet) -> CharSet {
        let extra = orbits.filter { $0.contains(where: set.contains) }.flatMap { $0.map { $0...$0 } }
        return extra.isEmpty ? set : CharSet(set.ranges + extra)
    }

    private static func canonicalize(_ unit: UInt16) -> UInt16 {
        guard let scalar = Unicode.Scalar(unit) else { return unit }
        let upper = Array(scalar.properties.uppercaseMapping.utf16)
        guard upper.count == 1, unit < 128 || upper[0] >= 128 else { return unit }
        return upper[0]
    }
}

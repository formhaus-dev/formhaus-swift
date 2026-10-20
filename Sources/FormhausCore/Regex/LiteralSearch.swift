struct LiteralSearch: Sendable {
    let literal: [UInt16]
    private let shifts: [UInt8]

    init(_ literal: [UInt16]) {
        self.literal = literal
        var shifts = [UInt8](repeating: UInt8(literal.count), count: literal.count > 1 ? 256 : 0)
        for (index, unit) in literal.dropLast().enumerated() { shifts[Int(unit & 0xFF)] = UInt8(literal.count - 1 - index) }
        self.shifts = shifts
    }

    func index(in text: [UInt16], from origin: Int) -> Int? {
        guard let tail = literal.last else { return origin <= text.count ? origin : nil }
        let last = literal.count - 1
        return text.withUnsafeBufferPointer { text in
            guard last > 0 else { return text[origin...].firstIndex(of: tail) }
            return literal.withUnsafeBufferPointer { literal in
                shifts.withUnsafeBufferPointer { shifts in
                    var start = origin
                    while start + last < text.count {
                        let unit = text[start + last]
                        if unit == tail, (0..<last).allSatisfy({ text[start + $0] == literal[$0] }) { return start }
                        start += Int(shifts[Int(unit & 0xFF)])
                    }
                    return nil
                }
            }
        }
    }
}

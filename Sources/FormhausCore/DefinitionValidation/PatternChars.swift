struct CharRange: Equatable {
    let low: Int
    let high: Int

    init(_ low: Int, _ high: Int) {
        self.low = low
        self.high = high
    }
}

typealias PatternChars = [CharRange]

private let maxUnit = 0xFFFF
private let anyUnit: PatternChars = [CharRange(0, maxUnit)]
private let digitUnits: PatternChars = [CharRange(48, 57)]
private let wordUnits: PatternChars = [CharRange(48, 57), CharRange(65, 90), CharRange(95, 95), CharRange(97, 122)]
private let spaceUnits: PatternChars = [
    CharRange(9, 13), CharRange(32, 32), CharRange(160, 160), CharRange(5760, 5760), CharRange(8192, 8202), CharRange(8232, 8233),
    CharRange(8239, 8239), CharRange(8287, 8287), CharRange(12288, 12288), CharRange(65279, 65279),
]
private let lineBreaks: PatternChars = [CharRange(10, 10), CharRange(13, 13), CharRange(8232, 8233)]
private let controls: [UInt16: Int] = [code("n"): 10, code("t"): 9, code("r"): 13, code("f"): 12, code("v"): 11]
private let classes: [UInt16: PatternChars] = [code("d"): digitUnits, code("w"): wordUnits, code("s"): spaceUnits]

private func complement(_ set: PatternChars) -> PatternChars {
    let sorted = set.enumerated().sorted { ($0.element.low, $0.offset) < ($1.element.low, $1.offset) }.map(\.element)
    var result: PatternChars = []
    var next = 0
    for range in sorted {
        if range.low > next { result.append(CharRange(next, range.low - 1)) }
        next = max(next, range.high + 1)
    }
    if next <= maxUnit { result.append(CharRange(next, maxUnit)) }
    return result
}

func overlaps(_ left: PatternChars, _ right: PatternChars) -> Bool {
    left.contains { range in right.contains { range.low <= $0.high && $0.low <= range.high } }
}

private func single(_ unit: Int) -> PatternChars {
    [CharRange(unit, unit)]
}

private func isLower(_ unit: UInt16) -> Bool {
    (code("a")...code("z")).contains(unit)
}

private func classEscape(_ letter: UInt16) -> PatternChars? {
    let lower = (code("A")...code("Z")).contains(letter) ? letter | 0x20 : letter
    guard let set = classes[lower] else { return nil }
    return lower == letter ? set : complement(set)
}

private struct Read {
    var set: PatternChars?
    var unit: Int?
    let end: Int
}

private struct AtomReader {
    let units: [UInt16]

    func at(_ index: Int) -> UInt16? {
        units.indices.contains(index) ? units[index] : nil
    }

    private func hex(_ start: Int, _ count: Int) -> Int? {
        guard start + count <= units.count else { return nil }
        var value = 0
        for unit in units[start..<start + count] {
            guard let digit = Int(String(decoding: [unit], as: UTF16.self), radix: 16) else { return nil }
            value = value * 16 + digit
        }
        return value
    }

    private func octal(_ start: Int) -> (value: Int, count: Int)? {
        guard let first = at(start), (code("0")...code("7")).contains(first) else { return nil }
        let limit = first <= code("3") ? 3 : 2
        var value = 0
        var count = 0
        while count < limit, let unit = at(start + count), (code("0")...code("7")).contains(unit) {
            value = value * 8 + Int(unit - code("0"))
            count += 1
        }
        return (value, count)
    }

    private func named(_ char: UInt16, _ index: Int, inClass: Bool) -> Read? {
        if let set = classEscape(char) { return Read(set: set, end: index + 1) }
        if let control = controls[char] { return Read(unit: control, end: index + 1) }
        return inClass && char == code("b") ? Read(unit: 8, end: index + 1) : nil
    }

    func escaped(_ index: Int, inClass: Bool) -> Read {
        let char = at(index) ?? code("\\")
        if let read = named(char, index, inClass: inClass) { return read }
        if char == code("x") || char == code("u") {
            let length = char == code("x") ? 2 : 4
            if let value = hex(index + 1, length) { return Read(unit: value, end: index + 1 + length) }
        }
        if char == code("c") {
            guard let letter = at(index + 1), isLower(letter | 0x20) else { return Read(unit: 92, end: index) }
            return Read(unit: Int(letter) % 32, end: index + 2)
        }
        if isDigit(char) {
            if char != code("0") && !inClass { return Read(set: anyUnit, end: units.count) }
            if let (value, count) = octal(index) { return Read(unit: value, end: index + count) }
        }
        if char == code("k") && !inClass { return Read(set: anyUnit, end: units.count) }
        return Read(unit: Int(char), end: index + 1)
    }

    private func member(_ index: Int) -> Read {
        units[index] == code("\\") ? escaped(index + 1, inClass: true) : Read(unit: Int(units[index]), end: index + 1)
    }

    func characterClass() -> PatternChars {
        let negated = at(1) == code("^")
        let end = units.count - 1
        var ranges: PatternChars = []
        var index = negated ? 2 : 1
        while index < end {
            let from = member(index)
            index = from.end
            if let set = from.set {
                ranges += set
                continue
            }
            let low = from.unit ?? 0
            if at(index) == code("-") && index + 1 < end, case let to = member(index + 1), let high = to.unit {
                ranges.append(CharRange(low, high))
                index = to.end
            } else {
                ranges.append(CharRange(low, low))
            }
        }
        return negated ? complement(ranges) : ranges
    }
}

func atomChars(_ atom: ArraySlice<UInt16>) -> PatternChars {
    let reader = AtomReader(units: Array(atom))
    switch reader.at(0) {
    case code("["): return reader.characterClass()
    case code("."): return complement(lineBreaks)
    case code("\\"):
        let read = reader.escaped(1, inClass: false)
        return read.set ?? single(read.unit ?? 0)
    default: return single(Int(reader.at(0) ?? 0))
    }
}

public typealias JSONObject = StringMap<JSONValue>
public typealias FieldErrors = StringMap<String>

func arrayIndex(_ key: String) -> UInt32? {
    let digits = key.utf8
    guard let first = digits.first, digits.count <= 10, first != 48 || digits.count == 1 else { return nil }
    var number: UInt64 = 0
    for digit in digits {
        guard digit >= 48 && digit <= 57 else { return nil }
        number = number * 10 + UInt64(digit - 48)
    }
    return number < UInt64(UInt32.max) ? UInt32(number) : nil
}

public struct StringMap<Value>: Sequence, ExpressibleByDictionaryLiteral {
    public private(set) var keys: [String] = []
    private var storage: [JSKey: Value] = [:]
    private var indexCount = 0
    private var insertionOrder = false

    public init() {}

    init(insertionOrder: Bool) {
        self.insertionOrder = insertionOrder
    }

    public init(dictionaryLiteral elements: (String, Value)...) {
        for (key, value) in elements { self[key] = value }
    }

    public var count: Int { keys.count }
    public var isEmpty: Bool { keys.isEmpty }

    public subscript(key: String) -> Value? {
        get { storage[JSKey(key)] }
        set {
            guard let newValue else {
                removeValue(forKey: key)
                return
            }
            if storage.updateValue(newValue, forKey: JSKey(key)) == nil { insertKey(key) }
        }
    }

    private mutating func insertKey(_ key: String) {
        guard !insertionOrder, let index = arrayIndex(key) else {
            keys.append(key)
            return
        }
        var low = 0
        var high = indexCount
        while low < high {
            let middle = (low + high) / 2
            if let current = arrayIndex(keys[middle]), current < index { low = middle + 1 } else { high = middle }
        }
        keys.insert(key, at: low)
        indexCount += 1
    }

    mutating func appendParsed(_ key: String, _ value: Value) {
        if storage.updateValue(value, forKey: JSKey(key)) == nil { keys.append(key) }
    }

    mutating func establishKeyOrder() {
        guard !insertionOrder else { return }
        var indexed: [(index: UInt32, key: String)] = []
        var named: [String] = []
        for key in keys {
            if let index = arrayIndex(key) { indexed.append((index, key)) } else { named.append(key) }
        }
        guard !indexed.isEmpty else { return }
        indexed.sort { $0.index < $1.index }
        keys = indexed.map(\.key) + named
        indexCount = indexed.count
    }

    subscript(key: String, default fallback: @autoclosure () -> Value) -> Value {
        get { self[key] ?? fallback() }
        set { self[key] = newValue }
    }

    public func has(_ key: String) -> Bool {
        storage[JSKey(key)] != nil
    }

    @discardableResult
    public mutating func removeValue(forKey key: String) -> Value? {
        guard let value = storage.removeValue(forKey: JSKey(key)) else { return nil }
        if let position = keys.lastIndex(where: { sameText($0, key) }) { keys.remove(at: position) }
        if !insertionOrder && arrayIndex(key) != nil { indexCount -= 1 }
        return value
    }

    public var values: [Value] {
        keys.compactMap { storage[JSKey($0)] }
    }

    public func makeIterator() -> AnyIterator<(key: String, value: Value)> {
        let storage = storage
        var pairs = keys.lazy.compactMap { key in storage[JSKey(key)].map { (key: key, value: $0) } }.makeIterator()
        return AnyIterator { pairs.next() }
    }

    mutating func merge(_ other: StringMap) {
        for (key, value) in other { self[key] = value }
    }

    func merging(_ other: StringMap) -> StringMap {
        var result = self
        result.merge(other)
        return result
    }
}

extension StringMap: Sendable where Value: Sendable {}

extension StringMap: Equatable where Value: Equatable {
    public static func == (lhs: StringMap, rhs: StringMap) -> Bool {
        lhs.storage == rhs.storage
    }
}

extension StringMap: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage)
    }
}

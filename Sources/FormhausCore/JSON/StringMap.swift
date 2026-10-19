public typealias JSONObject = StringMap<JSONValue>
public typealias FieldErrors = StringMap<String>

func arrayIndex(_ key: String) -> UInt32? {
    let digits = Array(key.utf8)
    guard !digits.isEmpty, digits.count <= 10, digits.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
    guard digits.count == 1 || digits[0] != 48 else { return nil }
    guard let number = UInt64(key), number < UInt64(UInt32.max) else { return nil }
    return UInt32(number)
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
            if arrayIndex(keys[middle])! < index { low = middle + 1 } else { high = middle }
        }
        keys.insert(key, at: low)
        indexCount += 1
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
        keys.removeAll { sameText($0, key) }
        if !insertionOrder && arrayIndex(key) != nil { indexCount -= 1 }
        return value
    }

    public var values: [Value] {
        keys.map { storage[JSKey($0)]! }
    }

    public func makeIterator() -> AnyIterator<(key: String, value: Value)> {
        var index = 0
        let keys = keys
        let storage = storage
        return AnyIterator {
            guard index < keys.count else { return nil }
            defer { index += 1 }
            return (keys[index], storage[JSKey(keys[index])]!)
        }
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

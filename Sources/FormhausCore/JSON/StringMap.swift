public typealias JSONObject = StringMap<JSONValue>
public typealias FieldErrors = StringMap<String>

public struct StringMap<Value>: Sequence, ExpressibleByDictionaryLiteral {
    public private(set) var keys: [String] = []
    private var storage: [JSKey: Value] = [:]

    public init() {}

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
            if storage.updateValue(newValue, forKey: JSKey(key)) == nil { keys.append(key) }
        }
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

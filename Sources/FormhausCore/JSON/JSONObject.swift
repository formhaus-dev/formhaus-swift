public struct JSONObject: Sendable, Hashable, Sequence, ExpressibleByDictionaryLiteral {
    public private(set) var keys: [String] = []
    private var storage: [String: JSONValue] = [:]

    public init() {}

    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        for (key, value) in elements { self[key] = value }
    }

    public var count: Int { keys.count }
    public var isEmpty: Bool { keys.isEmpty }

    public subscript(key: String) -> JSONValue? {
        get { storage[key] }
        set {
            guard let newValue else {
                removeValue(forKey: key)
                return
            }
            if storage.updateValue(newValue, forKey: key) == nil { keys.append(key) }
        }
    }

    public func has(_ key: String) -> Bool {
        storage[key] != nil
    }

    @discardableResult
    public mutating func removeValue(forKey key: String) -> JSONValue? {
        guard let value = storage.removeValue(forKey: key) else { return nil }
        keys.removeAll { $0 == key }
        return value
    }

    public var values: [JSONValue] {
        keys.map { storage[$0]! }
    }

    public func makeIterator() -> AnyIterator<(key: String, value: JSONValue)> {
        var index = 0
        let keys = keys
        let storage = storage
        return AnyIterator {
            guard index < keys.count else { return nil }
            defer { index += 1 }
            return (keys[index], storage[keys[index]]!)
        }
    }

    public static func == (lhs: JSONObject, rhs: JSONObject) -> Bool {
        lhs.storage == rhs.storage
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage)
    }

    mutating func merge(_ other: JSONObject) {
        for (key, value) in other { self[key] = value }
    }
}

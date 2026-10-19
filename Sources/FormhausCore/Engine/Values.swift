import Foundation

private final class TokenSource: @unchecked Sendable {
    private let lock = NSLock()
    private var last = 0

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        last += 1
        return last
    }
}

private let tokenSource = TokenSource()

func freshToken() -> Int { tokenSource.next() }

struct Ref: Sendable, Equatable {
    var token: Int
    var items: [Int]

    static func fresh(_ value: JSONValue?) -> Ref? {
        switch value {
        case .array(let items)?: Ref(token: freshToken(), items: items.map { _ in freshToken() })
        case .object?: Ref(token: freshToken(), items: [])
        default: nil
        }
    }

    static func preset(_ value: JSONValue, _ ordinal: Int) -> Ref? {
        let base = -(ordinal + 1) * 1_000_000
        switch value {
        case .array(let items): return Ref(token: -(ordinal + 1), items: items.indices.map { base - $0 - 1 })
        case .object: return Ref(token: -(ordinal + 1), items: [])
        default: return nil
        }
    }

    func replacing(_ items: [Int]) -> Ref {
        Ref(token: freshToken(), items: items)
    }
}

struct ValueSlot: Sendable {
    var value: JSONValue?
    var ref: Ref?

    init(_ value: JSONValue?, ref: Ref?) {
        self.value = value
        self.ref = value == nil ? nil : ref
    }

    static func fresh(_ value: JSONValue?) -> ValueSlot {
        ValueSlot(value, ref: Ref.fresh(value))
    }

    func isSame(_ other: ValueSlot) -> Bool {
        if let ref, let otherRef = other.ref { return ref.token == otherRef.token }
        return samePrimitive(value, other.value)
    }
}

func samePrimitive(_ lhs: JSONValue?, _ rhs: JSONValue?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil), (.null?, .null?): true
    case (.bool(let a)?, .bool(let b)?): a == b
    case (.number(let a)?, .number(let b)?): sameNumber(a, b)
    case (.string(let a)?, .string(let b)?): sameText(a, b)
    default: false
    }
}

struct Values: Sendable {
    private(set) var json = JSONObject()
    private var refs = StringMap<Ref>()

    init() {}

    init(fresh json: JSONObject) {
        for (key, value) in json { set(key, .fresh(value)) }
    }

    var keys: [String] { json.keys }

    subscript(key: String) -> JSONValue? { json[key] }

    func has(_ key: String) -> Bool { json.has(key) }

    func slot(_ key: String) -> ValueSlot { ValueSlot(json[key], ref: refs[key]) }

    mutating func set(_ key: String, _ slot: ValueSlot) {
        guard let value = slot.value else {
            remove(key)
            return
        }
        json[key] = value
        refs[key] = slot.ref ?? Ref.fresh(value)
    }

    mutating func remove(_ key: String) {
        json.removeValue(forKey: key)
        refs.removeValue(forKey: key)
    }

    mutating func merge(_ other: Values) {
        for key in other.keys { set(key, other.slot(key)) }
    }

    func itemIds(_ key: String) -> [Int] {
        refs[key]?.items ?? []
    }

    func itemId(_ key: String, _ index: Int) -> Int? {
        let ids = itemIds(key)
        return ids.indices.contains(index) ? ids[index] : nil
    }

    func changedKeys(_ other: Values) -> KeySet {
        var changed = KeySet()
        for key in keys + other.keys where !slot(key).isSame(other.slot(key)) { changed.insert(key) }
        return changed
    }
}

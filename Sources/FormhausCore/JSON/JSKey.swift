struct JSKey: Hashable, Sendable {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    static func == (lhs: JSKey, rhs: JSKey) -> Bool {
        sameText(lhs.text, rhs.text)
    }

    func hash(into hasher: inout Hasher) {
        for byte in text.utf8 { hasher.combine(byte) }
        hasher.combine(0xFF as UInt8)
    }
}

func sameText(_ lhs: String, _ rhs: String) -> Bool {
    lhs.utf8.elementsEqual(rhs.utf8)
}

func hasTextPrefix(_ text: String, _ prefix: String) -> Bool {
    text.utf8.starts(with: prefix.utf8)
}

struct KeySet: Sendable {
    private var storage = Set<JSKey>()

    init() {}

    init(_ items: some Sequence<String>) {
        for item in items { storage.insert(JSKey(item)) }
    }

    var isEmpty: Bool { storage.isEmpty }

    func contains(_ text: String) -> Bool { storage.contains(JSKey(text)) }

    @discardableResult
    mutating func insert(_ text: String) -> Bool { storage.insert(JSKey(text)).inserted }

    mutating func remove(_ text: String) { storage.remove(JSKey(text)) }

    mutating func formUnion(_ items: some Sequence<String>) {
        for item in items { insert(item) }
    }
}

extension Sequence where Element == String {
    func containsText(_ text: String) -> Bool {
        contains { sameText($0, text) }
    }
}

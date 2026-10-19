let maxListItems = 1000

struct ListLimits: Sendable {
    static let standard = ListLimits(lengths: StringMap())

    private let lengths: StringMap<Int>

    private init(lengths: StringMap<Int>) {
        self.lengths = lengths
    }

    init(_ fields: [FormField]) {
        var lengths = StringMap<Int>()
        for field in fields.flatMap({ [$0] + $0.items }) where listTypes.contains(field.type) && !field.hasOptionsFrom {
            let count = field.options?.count ?? 0
            if count > maxListItems { lengths[field.key] = max(lengths[field.key] ?? 0, count) }
        }
        self.lengths = lengths
    }

    func contains(_ key: String, _ value: JSONValue?, _ operand: JSONValue?) -> Bool {
        guard let items = value?.arrayValue, items.count <= maxListItems || items.count <= lengths[key] ?? 0 else { return false }
        return items.contains { sameValueZero($0, operand) }
    }
}

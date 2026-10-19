let maxListItems = 1000

private func exemptLength(_ field: FormField) -> Int? {
    guard listTypes.contains(field.type), !field.hasOptionsFrom, let count = field.options?.count, count > maxListItems else { return nil }
    return count
}

struct ListLimits: Sendable {
    static let standard = ListLimits()

    private var lengths = StringMap<Int>()

    mutating func trim(_ fields: [FormField]) {
        for field in fields.flatMap({ [$0] + $0.items }) { lengths[field.key] = exemptLength(field) }
    }

    func contains(_ key: String, _ value: JSONValue?, _ operand: JSONValue?) -> Bool {
        guard let items = value?.arrayValue, items.count <= maxListItems || items.count <= lengths[key] ?? 0 else { return false }
        return items.contains { sameValueZero($0, operand) }
    }
}

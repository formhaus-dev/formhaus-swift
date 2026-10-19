func isBlank(_ value: JSONValue?) -> Bool {
    switch value {
    case nil, .null?: true
    case .string(let text)?: text.isEmpty
    case .array(let items)?: items.isEmpty
    default: false
    }
}

private func toNumber(_ value: JSONValue?) -> Double? {
    let number: Double?
    switch value {
    case .string(let text)? where !text.isBlankText: number = jsNumber(fromString: text)
    case .number(let value)?: number = value
    default: number = nil
    }
    guard let number, number.isFinite else { return nil }
    return number
}

private func compare(_ value: JSONValue?, _ operand: JSONValue?, _ test: (Double, Double) -> Bool) -> Bool {
    guard let left = toNumber(value), let right = operand?.numberValue else { return false }
    return test(left, right)
}

public func evaluateCondition(_ condition: ShowCondition, _ values: JSONObject) -> Bool {
    guard let field = condition.field, let name = conditionOperators.first(where: { condition.operand($0) != nil }) else {
        return false
    }
    let value = values[field]
    let operand = condition.operand(name)
    let list = operand?.arrayValue ?? []
    switch name {
    case "eq": return strictEquals(value, operand)
    case "neq": return !strictEquals(value, operand)
    case "in": return list.contains { sameValueZero($0, value) }
    case "notIn": return !list.contains { sameValueZero($0, value) }
    case "notEmpty": return !(operand?.isTruthy ?? false) || !isBlank(value)
    case "gt": return compare(value, operand, >)
    case "gte": return compare(value, operand, >=)
    case "lt": return compare(value, operand, <)
    default: return compare(value, operand, <=)
    }
}

func isVisible(_ node: Conditional, _ values: JSONObject) -> Bool {
    let matches = { (condition: ShowCondition) in evaluateCondition(condition, values) }
    let any = node.showAny ?? []
    return (node.show ?? []).allSatisfy(matches) && (any.isEmpty || any.contains(where: matches))
}

public func isActionDisabled(_ action: FormAction?, _ values: JSONObject) -> Bool {
    guard let disabled = action?.disabled, !disabled.isEmpty else { return false }
    return disabled.allSatisfy { evaluateCondition($0, values) }
}

public func isVisible(_ field: FormField, _ values: JSONObject) -> Bool {
    isVisible(field as Conditional, values)
}

func valueFields(_ nodes: [FormNode]) -> [FormField] {
    nodes.flatMap { node -> [FormField] in
        switch node {
        case .field(let field): [field]
        case .section(let section): section.fields.compactMap(\.field)
        }
    }
}

func shownFields(_ nodes: [FormNode], _ values: JSONObject) -> [FormField] {
    nodes.flatMap { node -> [FormField] in
        guard isVisible(node.conditional, values) else { return [] }
        switch node {
        case .field(let field): return [field]
        case .section(let section): return section.fields.compactMap(\.field).filter { isVisible($0 as Conditional, values) }
        }
    }
}

func itemsOf(_ value: JSONValue?) -> [JSONValue] {
    value?.arrayValue ?? []
}

func itemScope(_ group: FormField, _ item: JSONValue, _ values: JSONObject) -> JSONObject {
    var scope = values
    let source = item.objectValue ?? JSONObject()
    for field in group.items { scope[field.key] = trimValue(field, source[field.key]) }
    return scope
}

func cleanItems(_ group: FormField, _ value: JSONValue?, _ values: JSONObject) -> JSONValue? {
    guard let items = value?.arrayValue else { return value }
    return .array(
        items.map { item in
            guard item.objectValue != nil else { return item }
            let scope = itemScope(group, item, values)
            var result = JSONObject()
            for field in group.items where scope[field.key] != nil && isVisible(field as Conditional, scope) {
                result[field.key] = scope[field.key]
            }
            return .object(result)
        }
    )
}

func itemPath(_ group: String, _ index: Int, _ field: String) -> String {
    "\(group).\(index).\(field)"
}

func splitPath(_ group: String, _ key: String) -> (Int, String)? {
    let prefix = Array("\(group).".utf8)
    let bytes = Array(key.utf8)
    guard bytes.starts(with: prefix) else { return nil }
    let rest = bytes[prefix.count...]
    guard let dot = rest.firstIndex(of: UInt8(ascii: ".")), dot != rest.startIndex else { return nil }
    let digits = rest[..<dot]
    let field = rest[(dot + 1)...]
    guard !field.isEmpty, digits.allSatisfy({ (0x30...0x39).contains($0) }), digits.count == 1 || digits.first != 0x30,
        let index = Int(String(decoding: digits, as: UTF8.self))
    else { return nil }
    return (index, String(decoding: field, as: UTF8.self))
}

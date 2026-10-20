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
    evaluateCondition(condition, values, limits: .standard)
}

func evaluateCondition(_ condition: ShowCondition, _ values: JSONObject, limits: ListLimits) -> Bool {
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
    case "contains": return limits.contains(field, value, operand)
    case "notContains": return !limits.contains(field, value, operand)
    case "notEmpty": return !(operand?.isTruthy ?? false) || !isBlank(value)
    case "gt": return compare(value, operand, >)
    case "gte": return compare(value, operand, >=)
    case "lt": return compare(value, operand, <)
    default: return compare(value, operand, <=)
    }
}

public func isVisible(_ node: some Conditional, _ values: JSONObject) -> Bool {
    isVisible(node, values, limits: .standard)
}

func isVisible(_ node: some Conditional, _ values: JSONObject, limits: ListLimits) -> Bool {
    let matches = { (condition: ShowCondition) in evaluateCondition(condition, values, limits: limits) }
    let any = node.showAny ?? []
    return (node.show ?? []).allSatisfy(matches) && (any.isEmpty || any.contains(where: matches))
}

public func isActionDisabled(_ action: FormAction?, _ values: JSONObject) -> Bool {
    isActionDisabled(action, values, limits: .standard)
}

func isActionDisabled(_ action: FormAction?, _ values: JSONObject, limits: ListLimits) -> Bool {
    guard let disabled = action?.disabled, !disabled.isEmpty else { return false }
    return disabled.allSatisfy { evaluateCondition($0, values, limits: limits) }
}

func valueFields(_ nodes: [FormNode]) -> [FormField] {
    nodes.flatMap { node -> [FormField] in
        switch node {
        case .field(let field): [field]
        case .section(let section): section.fields.compactMap(\.field)
        }
    }
}

func shownFields(_ nodes: [FormNode], _ values: JSONObject, _ limits: ListLimits) -> [FormField] {
    nodes.flatMap { node -> [FormField] in
        guard isVisible(node, values, limits: limits) else { return [] }
        switch node {
        case .field(let field): return [field]
        case .section(let section): return section.fields.compactMap(\.field).filter { isVisible($0, values, limits: limits) }
        }
    }
}

func itemsOf(_ value: JSONValue?) -> [JSONValue] {
    value?.arrayValue ?? []
}

func itemScope(_ group: FormField, _ item: JSONValue, _ values: JSONObject) -> JSONObject {
    itemScope(group.items, item, values)
}

func itemScope(_ fields: [FormField], _ item: JSONValue, _ values: JSONObject) -> JSONObject {
    var scope = values
    let source = item.objectValue ?? JSONObject()
    for field in fields { scope[field.key] = trimValue(field, source[field.key]) }
    return scope
}

func cleanItems(_ group: FormField, _ value: JSONValue?, _ values: JSONObject, _ limits: ListLimits) -> JSONValue? {
    guard let items = value?.arrayValue else { return value }
    let fields = group.items
    return .array(items.map { cleanItem(fields, $0, values, limits) })
}

func cleanItem(_ fields: [FormField], _ item: JSONValue, _ values: JSONObject, _ limits: ListLimits) -> JSONValue {
    guard item.objectValue != nil else { return item }
    let scope = itemScope(fields, item, values)
    var result = JSONObject()
    for field in fields where scope[field.key] != nil && isVisible(field, scope, limits: limits) {
        result[field.key] = scope[field.key]
    }
    return .object(result)
}

func itemPath(_ group: String, _ index: Int, _ field: String) -> String {
    "\(group).\(index).\(field)"
}

func splitPath(_ group: String, _ key: String) -> (Int, String)? {
    let prefix = "\(group).".utf8
    guard key.utf8.starts(with: prefix) else { return nil }
    let rest = key.utf8.dropFirst(prefix.count)
    guard let dot = rest.firstIndex(of: UInt8(ascii: ".")), dot != rest.startIndex else { return nil }
    let digits = rest[..<dot]
    let field = rest[rest.index(after: dot)...]
    guard !field.isEmpty, digits.allSatisfy({ (0x30...0x39).contains($0) }), digits.count == 1 || digits.first != 0x30,
        let index = Int(Substring(digits))
    else { return nil }
    return (index, String(Substring(field)))
}

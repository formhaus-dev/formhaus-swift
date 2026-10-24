public struct RevealTarget: Sendable, Hashable {
    public let parent: Int
    public let option: Int

    public init(parent: Int, option: Int) {
        self.parent = parent
        self.option = option
    }
}

private enum RevealKey: Hashable {
    case text(JSKey)
    case number(Double)
    case flag(Bool)
    case null

    init?(_ value: JSONValue?) {
        switch value {
        case .string(let text)?: self = .text(JSKey(text))
        case .number(let number)?: self = .number(number)
        case .bool(let flag)?: self = .flag(flag)
        case .null?: self = .null
        default: return nil
        }
    }
}

private struct RevealParent {
    let field: FormField
    let operatorName: String
    let multiple: Bool
    let randomize: Bool
    let positions: [RevealKey: Int]

    init?(_ node: FormNode) {
        guard let field = node.field, let options = field.json["options"]?.arrayValue, !options.isEmpty,
            !field.hasOptionsFrom, field.layout != .string("inline"), !options.contains(where: { $0["image"]?.isTruthy == true })
        else { return nil }
        switch field.type {
        case "radio": operatorName = "eq"
        case "multiselect": operatorName = "contains"
        default: return nil
        }
        self.field = field
        multiple = field.type == "multiselect"
        randomize = field.randomize
        var positions: [RevealKey: Int] = [:]
        for (position, option) in options.enumerated().reversed() {
            if let key = RevealKey(option["value"]) { positions[key] = position }
        }
        self.positions = positions
    }

    func option(of node: FormNode) -> Int? {
        guard let child = node.field, child.type != "group", child.type != "hidden" else { return nil }
        let conditions = (child.json["show"]?.arrayValue ?? []) + (child.json["showAny"]?.arrayValue ?? [])
        guard conditions.count == 1, let condition = conditions[0].objectValue,
            strictEquals(condition["field"], field.json["key"]),
            conditionOperators.first(where: condition.has) == operatorName
        else { return nil }
        return RevealKey(condition[operatorName]).flatMap { positions[$0] }
    }
}

public func revealTargets(_ nodes: [FormNode]) -> [RevealTarget?] {
    var targets = [RevealTarget?](repeating: nil, count: nodes.count)
    for (index, node) in nodes.enumerated() {
        guard let parent = RevealParent(node) else { continue }
        var last = -1
        for at in nodes.indices.dropFirst(index + 1) {
            guard let option = parent.option(of: nodes[at]) else { break }
            if parent.multiple && (option < last || parent.randomize && last >= 0 && option != last) { break }
            if targets[at] == nil { targets[at] = RevealTarget(parent: index, option: option) }
            last = option
        }
    }
    return targets
}

let conditionOperators = ["eq", "neq", "in", "notIn", "contains", "notContains", "notEmpty", "gt", "gte", "lt", "lte"]

public struct ShowCondition: Sendable, Hashable {
    let json: JSONObject

    init(json: JSONObject) {
        self.json = json
    }

    public var field: String? { json["field"]?.stringValue }

    public var operatorName: String? {
        conditionOperators.first { json.has($0) }
    }

    public func operand(_ name: String) -> JSONValue? { json[name] }
}

public protocol Conditional {
    var show: [ShowCondition]? { get }
    var showAny: [ShowCondition]? { get }
}

extension Conditional {
    var conditionFields: [String] {
        ((show ?? []) + (showAny ?? [])).compactMap(\.field)
    }

    var isConditioned: Bool { show != nil || showAny != nil }
}

func conditions(_ value: JSONValue?) -> [ShowCondition]? {
    guard let items = value?.arrayValue else { return nil }
    return items.compactMap { $0.objectValue.map(ShowCondition.init(json:)) }
}

public struct FormAction: Sendable, Hashable {
    let json: JSONObject

    init(json: JSONObject) {
        self.json = json
    }

    public var label: String? { json["label"]?.stringValue }
    public var variant: String? { json["variant"]?.stringValue }
    public var disabled: [ShowCondition]? { conditions(json["disabled"]) }
}

public struct StepRoute: Sendable, Hashable, Conditional {
    let json: JSONObject

    init(json: JSONObject) {
        self.json = json
    }

    public var to: String? { json["to"]?.stringValue }
    public var endsForm: Bool { json["to"]?.isNull == true }
    public var show: [ShowCondition]? { conditions(json["show"]) }
    public var showAny: [ShowCondition]? { conditions(json["showAny"]) }
}

public enum StepButton: Sendable, Hashable {
    case absent
    case hidden
    case action(FormAction)

    init(_ value: JSONValue?) {
        switch value {
        case .bool(false)?: self = .hidden
        case .object(let object)?: self = .action(FormAction(json: object))
        default: self = .absent
        }
    }

    public var action: FormAction? {
        if case .action(let action) = self { return action }
        return nil
    }
}

public enum ConditionRule: Sendable, Hashable {
    case fixed(Bool)
    case conditions([ShowCondition])

    init?(_ value: JSONValue?) {
        switch value {
        case nil: return nil
        case .bool(let flag)?: self = .fixed(flag)
        case .array(let items)?:
            let list = items.compactMap { $0.objectValue.map(ShowCondition.init(json:)) }
            self = list.isEmpty || list.count != items.count ? .fixed(false) : .conditions(list)
        default: self = .fixed(false)
        }
    }

    public var isConditional: Bool {
        if case .conditions = self { return true }
        return false
    }

    public func isMet(_ values: JSONObject) -> Bool {
        isMet(values, limits: .standard)
    }

    func isMet(_ values: JSONObject, limits: ListLimits) -> Bool {
        switch self {
        case .fixed(let flag): flag
        case .conditions(let list): list.allSatisfy { evaluateCondition($0, values, limits: limits) }
        }
    }
}

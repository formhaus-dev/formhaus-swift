public let conditionOperators = ["eq", "neq", "in", "notIn", "notEmpty", "gt", "gte", "lt", "lte"]

public struct ShowCondition: Sendable, Hashable {
    public let json: JSONObject

    public init(json: JSONObject) {
        self.json = json
    }

    public var field: String? { json["field"]?.stringValue }

    public var operatorName: String? {
        conditionOperators.first { json.has($0) }
    }

    public func operand(_ name: String) -> JSONValue? { json[name] }
}

protocol Conditional {
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
    public let json: JSONObject

    public init(json: JSONObject) {
        self.json = json
    }

    public var label: String? { json["label"]?.stringValue }
    public var disabled: [ShowCondition]? { conditions(json["disabled"]) }
}

public struct StepRoute: Sendable, Hashable, Conditional {
    public let json: JSONObject

    public init(json: JSONObject) {
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

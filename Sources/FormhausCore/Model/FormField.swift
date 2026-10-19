public struct FieldOption: Sendable, Hashable {
    public let json: JSONObject

    public var value: String? { json["value"]?.stringValue }
    public var label: String? { json["label"]?.stringValue }
}

public struct FieldValidation: Sendable, Hashable {
    public let json: JSONObject

    public var required: JSONValue? { json["required"] }
    public var minLength: Double? { json["minLength"]?.numberValue }
    public var maxLength: Double? { json["maxLength"]?.numberValue }
    public var min: Double? { json["min"]?.numberValue }
    public var max: Double? { json["max"]?.numberValue }
    public var pattern: String? { json["pattern"]?.stringValue }
    public var matchField: String? { json["matchField"]?.stringValue }
    public var validator: String? { json["validator"]?.stringValue }

    func message(_ name: String) -> String? { json[name]?.stringValue }
}

public final class FormField: Sendable, Conditional {
    public let json: JSONObject
    public let key: String
    public let type: String
    public let show: [ShowCondition]?
    public let showAny: [ShowCondition]?
    public let validation: FieldValidation?
    public let options: [FieldOption]?
    public let fields: [FormNode]?

    init(json: JSONObject) {
        self.json = json
        key = json["key"]?.stringValue ?? ""
        type = json["type"]?.stringValue ?? ""
        show = conditions(json["show"])
        showAny = conditions(json["showAny"])
        validation = json["validation"]?.objectValue.map(FieldValidation.init(json:))
        options = json["options"]?.arrayValue.map { $0.compactMap { $0.objectValue.map(FieldOption.init(json:)) } }
        fields = type == "group" ? formNodes(json["fields"]) : nil
    }

    public var label: String? { json["label"]?.stringValue }
    public var defaultValue: JSONValue? { json["defaultValue"] }
    public var source: JSONValue? { json["source"] }
    public var optionsFrom: JSONValue? { json["optionsFrom"] }
    public var hasOptionsFrom: Bool { optionsFrom?.isTruthy == true }
    public var defaultItems: Double? { json["defaultItems"]?.numberValue }
    public var isGroup: Bool { type == "group" }

    public var optionsDependsOn: [String]? {
        json["optionsDependsOn"]?.arrayValue?.compactMap(\.stringValue)
    }

    public var items: [FormField] {
        (fields ?? []).compactMap(\.field)
    }
}

public final class FormSection: Sendable, Conditional {
    public let json: JSONObject
    public let key: String
    public let show: [ShowCondition]?
    public let showAny: [ShowCondition]?
    public let fields: [FormNode]

    init(json: JSONObject) {
        self.json = json
        key = json["key"]?.stringValue ?? ""
        show = conditions(json["show"])
        showAny = conditions(json["showAny"])
        fields = formNodes(json["fields"]) ?? []
    }

    public var title: String? { json["title"]?.stringValue }
}

public enum FormNode: Sendable {
    case field(FormField)
    case section(FormSection)

    public var key: String {
        switch self {
        case .field(let field): field.key
        case .section(let section): section.key
        }
    }

    public var type: String {
        switch self {
        case .field(let field): field.type
        case .section: "section"
        }
    }

    public var json: JSONObject {
        switch self {
        case .field(let field): field.json
        case .section(let section): section.json
        }
    }

    public var field: FormField? {
        if case .field(let field) = self { return field }
        return nil
    }

    public var section: FormSection? {
        if case .section(let section) = self { return section }
        return nil
    }

    var conditional: Conditional {
        switch self {
        case .field(let field): field
        case .section(let section): section
        }
    }

    var children: [FormNode]? {
        switch self {
        case .field(let field): field.fields
        case .section(let section): section.fields
        }
    }
}

func formNodes(_ value: JSONValue?) -> [FormNode]? {
    guard let items = value?.arrayValue else { return nil }
    return items.compactMap { item in
        guard let object = item.objectValue else { return nil }
        return object["type"]?.stringValue == "section" ? .section(FormSection(json: object)) : .field(FormField(json: object))
    }
}

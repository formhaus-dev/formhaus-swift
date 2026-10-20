public struct FieldOption: Sendable, Hashable {
    let json: JSONObject
    let imageDigest: Int?

    init(json: JSONObject) {
        self.json = json
        imageDigest = json["image"]?.stringValue.map { image in
            var hasher = Hasher()
            hasher.combine(image)
            return hasher.finalize()
        }
    }

    public var value: String? { json["value"]?.stringValue }
    public var label: String? { json["label"]?.stringValue }
    public var image: String? { json["image"]?.stringValue }
    public var exclusive: Bool { json["exclusive"]?.isTruthy == true }
}

public struct FieldValidation: Sendable, Hashable {
    let json: JSONObject

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

public struct FormField: Sendable, Conditional, NodeIdentity {
    var json: JSONObject
    let ordinal: Int
    public let key: String
    public let type: String
    public let show: [ShowCondition]?
    public let showAny: [ShowCondition]?
    public let validation: FieldValidation?
    public let options: [FieldOption]?
    public let fields: [FormNode]?

    init(json: JSONObject, ordinals: inout Int) {
        self.json = json
        ordinal = nextOrdinal(&ordinals)
        key = json["key"]?.stringValue ?? ""
        type = json["type"]?.stringValue ?? ""
        show = conditions(json["show"])
        showAny = conditions(json["showAny"])
        validation = json["validation"]?.objectValue.map(FieldValidation.init(json:))
        options = json["options"]?.arrayValue.map { $0.compactMap { $0.objectValue.map(FieldOption.init(json:)) } }
        fields = type == "group" ? formNodes(json["fields"], &ordinals) : nil
    }

    public var label: String? { json["label"]?.stringValue }
    public var placeholder: String? { json["placeholder"]?.stringValue }
    public var helperText: String? { json["helperText"]?.stringValue }
    public var itemLabel: String? { json["itemLabel"]?.stringValue }
    public var addLabel: String? { json["addLabel"]?.stringValue }
    public var removeLabel: String? { json["removeLabel"]?.stringValue }
    public var layout: JSONValue? { json["layout"] }
    public var columns: Int? { json["columns"]?.numberValue.flatMap { Int(exactly: $0) } }
    public var accept: JSONValue? { json["accept"] }
    public var rows: JSONValue? { json["rows"] }
    public var mask: JSONValue? { json["mask"] }
    public var inputMode: JSONValue? { json["inputMode"] }
    public var autocomplete: JSONValue? { json["autocomplete"] }
    public var autoAdvance: JSONValue? { json["autoAdvance"] }
    public var props: JSONObject? { json["props"]?.objectValue }
    public var defaultValue: JSONValue? { json["defaultValue"] }
    public var source: JSONValue? { json["source"] }
    public var optionsFrom: JSONValue? { json["optionsFrom"] }
    public var hasOptionsFrom: Bool { optionsFrom?.isTruthy == true }
    public var defaultItems: Double? { json["defaultItems"]?.numberValue }
    public var isGroup: Bool { type == "group" }
    public var isScale: Bool { scaleTypes.contains(type) }

    var hasPictures: Bool {
        ["radio", "multiselect"].contains(type) && (options ?? []).contains { $0.image?.isEmpty == false }
    }

    public var scaleRange: (min: Double, max: Double)? {
        guard isScale else { return nil }
        return (type == "rating" ? 1 : validation?.min ?? 1, validation?.max ?? 5)
    }

    public var optionsDependsOn: [String]? {
        json["optionsDependsOn"]?.arrayValue?.compactMap(\.stringValue)
    }

    public var items: [FormField] {
        (fields ?? []).compactMap(\.field)
    }
}

public struct FormSection: Sendable, Conditional, NodeIdentity {
    var json: JSONObject
    let ordinal: Int
    public let key: String
    public let show: [ShowCondition]?
    public let showAny: [ShowCondition]?
    public internal(set) var fields: [FormNode]

    init(json: JSONObject, ordinals: inout Int) {
        self.json = json
        ordinal = nextOrdinal(&ordinals)
        key = json["key"]?.stringValue ?? ""
        show = conditions(json["show"])
        showAny = conditions(json["showAny"])
        fields = formNodes(json["fields"], &ordinals) ?? []
    }

    public var title: String? { json["title"]?.stringValue }
    public var description: String? { json["description"]?.stringValue }
    public var layout: String? { json["layout"]?.stringValue }
    public var isMatrix: Bool { layout == "matrix" }
}

public enum FormNode: Sendable, Conditional {
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

    var json: JSONObject {
        switch self {
        case .field(let field): field.json
        case .section(let section): section.json
        }
    }

    var ordinal: Int {
        switch self {
        case .field(let field): field.ordinal
        case .section(let section): section.ordinal
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

    public var show: [ShowCondition]? {
        switch self {
        case .field(let field): field.show
        case .section(let section): section.show
        }
    }

    public var showAny: [ShowCondition]? {
        switch self {
        case .field(let field): field.showAny
        case .section(let section): section.showAny
        }
    }

    var children: [FormNode]? {
        switch self {
        case .field(let field): field.fields
        case .section(let section): section.fields
        }
    }
}

protocol NodeIdentity {
    var ordinal: Int { get }
}

func nextOrdinal(_ ordinals: inout Int) -> Int {
    defer { ordinals += 1 }
    return ordinals
}

func formNodes(_ value: JSONValue?, _ ordinals: inout Int) -> [FormNode]? {
    guard let items = value?.arrayValue else { return nil }
    return items.compactMap { item in
        guard let object = item.objectValue else { return nil }
        if object["type"]?.stringValue == "section" { return .section(FormSection(json: object, ordinals: &ordinals)) }
        return .field(FormField(json: object, ordinals: &ordinals))
    }
}

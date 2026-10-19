public final class FormStep: Sendable, Conditional {
    public let json: JSONObject
    public let id: String
    public let fields: [FormNode]
    public let show: [ShowCondition]?
    public let showAny: [ShowCondition]?
    public let routes: [StepRoute]?
    public let next: StepButton
    public let back: StepButton
    public let skip: StepButton

    init(json: JSONObject) {
        self.json = json
        id = json["id"]?.stringValue ?? ""
        fields = formNodes(json["fields"]) ?? []
        show = conditions(json["show"])
        showAny = conditions(json["showAny"])
        routes = json["routes"]?.arrayValue.map { $0.compactMap { $0.objectValue.map(StepRoute.init(json:)) } }
        next = StepButton(json["next"])
        back = StepButton(json["back"])
        skip = StepButton(json["skip"])
    }

    public var title: String? { json["title"]?.stringValue }
    public var canSkip: Bool { json["skip"]?.isTruthy == true }

    func button(_ name: String) -> StepButton {
        switch name {
        case "next": next
        case "back": back
        default: skip
        }
    }
}

public final class FormDefinition: Sendable {
    public let json: JSONObject
    public let id: String
    public let submit: FormAction
    public let cancel: FormAction?
    public let fields: [FormNode]?
    public let steps: [FormStep]?

    init(unchecked json: JSONObject) {
        self.json = json
        id = json["id"]?.stringValue ?? ""
        submit = FormAction(json: json["submit"]?.objectValue ?? JSONObject())
        cancel = json["cancel"]?.objectValue.map(FormAction.init(json:))
        fields = formNodes(json["fields"])
        steps = json["steps"]?.arrayValue.map { $0.compactMap { $0.objectValue.map(FormStep.init(json:)) } }
    }

    public convenience init(json: JSONValue) throws(FormDefinitionError) {
        let errors = definitionIssues(json, warnings: false).filter(\.isError)
        guard errors.isEmpty, let object = json.objectValue else { throw FormDefinitionError(issues: errors) }
        self.init(unchecked: object)
    }

    public var title: String? { json["title"]?.stringValue }
    public var lang: String? { json["lang"]?.stringValue }
    public var formatVersion: String? { json["formatVersion"]?.stringValue }
    public var messages: JSONValue? { json["messages"] }
    public var labels: JSONValue? { json["labels"] }
    public var i18n: JSONValue? { json["i18n"] }
    public var isMultiStep: Bool { !(steps ?? []).isEmpty }

    var topNodes: [FormNode] {
        if let steps, !steps.isEmpty { return steps.flatMap(\.fields) }
        return fields ?? []
    }

    var allFields: [FormField] { valueFields(topNodes) }
}

public func parseDefinition(_ json: JSONValue) throws(FormDefinitionError) -> FormDefinition {
    try FormDefinition(json: json)
}

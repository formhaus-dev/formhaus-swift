public struct RecalledTexts: Sendable, Hashable {
    public let title: String?
    public let description: String?
    public let label: String?
    public let helperText: String?
    public let placeholder: String?

    init(_ json: JSONObject) {
        title = json["title"]?.stringValue
        description = json["description"]?.stringValue
        label = json["label"]?.stringValue
        helperText = json["helperText"]?.stringValue
        placeholder = json["placeholder"]?.stringValue
    }
}

extension FormEngine {
    private func scope() -> RecallScope {
        let visibility = core.visibility
        let values = core.values.json
        return RecallScope(
            visibility: visibility, values: getSubmitValues(), lang: options.lang, format: options.formatRecall
        ) { visibility.activeField($0, values) }
    }

    private func recalls(_ json: JSONObject) -> Bool {
        definition.recallsAnswers && recallSlots.contains { json[$0]?.stringValue.map(hasRecallBraces) == true }
    }

    private func recalledSlots(_ json: JSONObject, _ item: RecallItem?) -> JSONObject {
        guard recalls(json) else { return json }
        let resolve = scope().resolver(RecallOptions(item: item))
        var result = json
        for slot in recallSlots {
            if let text = json[slot]?.stringValue { result[slot] = .string(substitute(definition, text) { resolve }) }
        }
        return result
    }

    public func recallText(_ text: String, options: RecallOptions = RecallOptions()) -> String {
        substitute(definition, text) { scope().resolver(options) }
    }

    func recalled(_ field: FormField, at key: String? = nil) -> FormField {
        var copy = field
        copy.json = recalledSlots(field.json, key.flatMap(core.visibility.parse).map { RecallItem(group: $0.group, index: $0.index) })
        return copy
    }

    @_spi(Renderer)
    public func recalledTexts(_ field: FormField, at key: String? = nil) -> RecalledTexts {
        RecalledTexts(recalled(field, at: key).json)
    }

    @_spi(Renderer)
    public func recalledTexts(_ section: FormSection) -> RecalledTexts {
        RecalledTexts(recalledSlots(section.json, nil))
    }

    @_spi(Renderer)
    public func recalledTexts(_ step: FormStep) -> RecalledTexts {
        RecalledTexts(recalledSlots(step.json, nil))
    }

    func recalledTitle(_ json: JSONObject) -> String? {
        recalledSlots(json, nil)["title"]?.stringValue
    }

    func itemTemplate(_ template: String, _ item: RecallItem, _ params: JSONObject) -> String {
        substitute(definition, template, params: params) { scope().resolver(RecallOptions(item: item)) }
    }
}

protocol RecallNode {
    var json: JSONObject { get set }
}

extension FormField: RecallNode {}
extension FormSection: RecallNode {}
extension FormStep: RecallNode {}

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

    private func recalled<Node: RecallNode>(_ node: Node, _ item: RecallItem?) -> Node {
        var copy = node
        copy.json = recalledSlots(node.json, item)
        return copy
    }

    public func recallText(_ text: String, options: RecallOptions = RecallOptions()) -> String {
        substitute(definition, text) { scope().resolver(options) }
    }

    @_spi(Renderer)
    public func recalled(_ field: FormField, at key: String? = nil) -> FormField {
        recalled(field, key.flatMap(core.visibility.parse).map { RecallItem(group: $0.group, index: $0.index) })
    }

    @_spi(Renderer)
    public func recalled(_ section: FormSection) -> FormSection {
        recalled(section, nil)
    }

    @_spi(Renderer)
    public func recalled(_ step: FormStep) -> FormStep {
        recalled(step, nil)
    }

    func recalledTitle(_ json: JSONObject) -> String? {
        recalledSlots(json, nil)["title"]?.stringValue
    }

    func itemTemplate(_ template: String, _ item: RecallItem, _ params: JSONObject) -> String {
        substitute(definition, template, params: params) { scope().resolver(RecallOptions(item: item)) }
    }
}

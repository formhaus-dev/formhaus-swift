enum SlotKind {
    case text, rule, message, label
}

struct Slot {
    let kind: SlotKind
    let address: [String]
    let key: String?
    let source: String?
    let fallback: String
    let params: JSONObject
    let template: Bool
    let location: [String]
    let property: String
}

private let bounds = ["minLength": "min", "maxLength": "max", "min": "min", "max": "max"]

private func ruleKey(_ field: FormField, _ rule: String) -> String {
    (listTypes.contains(field.type) || field.isGroup) && rule.hasSuffix("Length")
        ? rule.replacingOccurrences(of: "Length", with: "Items") : rule
}

private func catalogKeys(_ value: JSONValue?) -> [String] {
    value?.objectValue?.keys ?? []
}

private func usedMessages(_ definition: FormDefinition) -> KeySet {
    var keys = KeySet(catalogKeys(definition.messages) + catalogKeys(definition.i18n?["messages"]))
    for field in definition.allFields.flatMap({ [$0] + $0.items }) {
        let rules = field.validation?.json ?? JSONObject()
        for rule in NodeKind.validation.slots
        where hasRule(rules, rule) && rules[rule == "required" ? rule : "\(rule)Message"]?.stringValue == nil {
            keys.insert(ruleKey(field, rule))
        }
        keys.formUnion(typeMessageKeys(field).map(\.rawValue))
    }
    return keys
}

private func nodeSlots(_ definition: FormDefinition, _ text: TextNode) -> [Slot] {
    let keys = text.node["i18n"]?.objectValue ?? JSONObject()
    return text.kind.slots.compactMap { slot -> Slot? in
        if text.kind != .validation {
            guard let source = text.node[slot]?.stringValue else { return nil }
            return Slot(
                kind: .text, address: slotAddress(text.kind, text.address, slot), key: keys[slot]?.stringValue, source: source,
                fallback: source, params: JSONObject(), template: true, location: text.location, property: slot
            )
        }
        guard hasRule(text.node, slot), let field = text.field else { return nil }
        let literalName = slot == "required" ? slot : "\(slot)Message"
        let literal = text.node[literalName]?.stringValue
        var params = JSONObject()
        if let bound = bounds[slot] { params[bound] = text.node[slot] }
        let message = ruleKey(field, slot)
        let fallback =
            literal
            ?? formatText(definition.messages?[message]?.stringValue ?? defaultMessages[MessageKey(rawValue: message)] ?? "", params)
        return Slot(
            kind: .rule, address: text.address + [slot], key: keys[slot]?.stringValue, source: literal, fallback: fallback,
            params: params, template: literal != nil || keys[slot]?.isTruthy == true, location: text.location, property: literalName
        )
    }
}

private func catalogSlots(_ definition: FormDefinition, _ name: String, _ used: KeySet) -> [Slot] {
    let isMessages = name == "messages"
    let order = isMessages ? defaultMessageKeys.map(\.rawValue) : defaultLabelKeys
    let fallback = { (item: String) in isMessages ? defaultMessages[MessageKey(rawValue: item)] : defaultLabels[item] }
    let keys = definition.i18n?[name]?.objectValue ?? JSONObject()
    return order.compactMap { item in
        guard let source = definition.json[name]?[item]?.stringValue ?? fallback(item) else { return nil }
        return Slot(
            kind: isMessages ? .message : .label, address: [name, item], key: keys[item]?.stringValue, source: source,
            fallback: source, params: JSONObject(), template: used.contains(item), location: [name], property: item
        )
    }
}

private let groupLabels = [
    "addItem", "removeItem", "itemLabel", "itemAdded", "itemRemoved", "removeItemNamed", "removeItemPrompt", "removeItemBody", "cancel",
]
private let pickerTypes = ["date", "time", "datetime"]

private func unlabeled(_ value: JSONValue?, _ key: String) -> Bool {
    value?[key]?.isTruthy != true
}

private func usedLabels(_ definition: FormDefinition) -> KeySet {
    let steps = definition.steps ?? []
    let nodes = definition.allFields
    let fields = nodes.flatMap { $0.isGroup ? $0.items : [$0] }
    var labels = KeySet(["errorSummary"])
    func add(_ when: Bool, _ keys: [String]) {
        if when { labels.formUnion(keys) }
    }
    add(!steps.isEmpty, ["continue", "back", "stepOf", "stepErrors"])
    add(steps.contains { $0.json["title"]?.isTruthy != true }, ["stepTitle"])
    add(steps.contains { $0.canSkip && unlabeled($0.json["skip"], "label") }, ["skip"])
    add(unlabeled(definition.json["submit"], "label"), ["submit"])
    add(nodes.contains(where: \.isGroup), groupLabels)
    add(fields.contains(where: \.hasPictures), ["enlargeImage", "close"])
    add(fields.contains { $0.type == "multiselect" && ($0.options ?? []).contains(where: \.exclusive) }, ["or"])
    add(fields.contains { $0.type == "select" }, ["select"])
    add(fields.contains { $0.validation?.required?.isTruthy == true }, ["required"])
    add(fields.contains { pickerTypes.contains($0.type) || $0.type == "file" }, ["clear"])
    add(fields.contains { pickerTypes.contains($0.type) }, ["done"])
    add(fields.contains { $0.type == "file" }, ["chooseFile"])
    return labels
}

func definitionSlots(_ definition: FormDefinition) -> [Slot] {
    return textNodes(definition).flatMap { nodeSlots(definition, $0) }
        + catalogSlots(definition, "messages", usedMessages(definition))
        + catalogSlots(definition, "labels", usedLabels(definition))
}

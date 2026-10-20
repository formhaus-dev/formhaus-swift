public struct Localized: Sendable {
    public let definition: FormDefinition
    public let messages: JSONValue
    public let labels: JSONValue
}

public struct TextSlot: Sendable, Hashable {
    public let address: String
    public let key: String?
    public let text: String
    public let params: [String]
    public let hash: String
}

func lookup(_ overlay: JSONValue?, _ path: [String]) -> String? {
    var node = overlay
    for key in path { node = node?.objectValue?[key] }
    guard let text = node?.stringValue, !text.isBlankText else { return nil }
    return text
}

func placeholders(_ text: String) -> [String] {
    OrderedKeys(templateTokens(text)).keys.sorted(by: codeUnitLess)
}

func translationKey(_ prefix: String?, _ explicit: String?, _ address: [String]) -> String? {
    if let explicit { return explicit }
    guard let prefix else { return nil }
    return (prefix.isEmpty ? address : [prefix] + address).joined(separator: ".")
}

func fnv1a(_ text: String) -> UInt32 {
    var hash: UInt32 = 0x811c_9dc5
    for scalar in text.unicodeScalars { hash = (hash ^ scalar.value) &* 0x0100_0193 }
    return hash
}

private func textHash(_ key: String?, _ text: String) -> String {
    let hex = String(fnv1a("\(key ?? "")\u{0}\(text)"), radix: 16)
    return String(repeating: "0", count: max(0, 8 - hex.count)) + hex
}

func describeSlot(_ slot: Slot, prefix: String?) -> TextSlot {
    let key = translationKey(prefix, slot.key, slot.address)
    let text = slot.source ?? slot.fallback
    let params = slot.kind == .rule ? slot.params.keys : placeholders(text)
    return TextSlot(address: slot.address.joined(separator: "."), key: key, text: text, params: params, hash: textHash(key, text))
}

public enum TranslationPrefix: Sendable, Hashable {
    case definitionId
    case custom(String)
    case none
}

public func textSlots(_ definition: FormDefinition, prefix: TranslationPrefix = .definitionId) -> [TextSlot] {
    let resolved: String? =
        switch prefix {
        case .definitionId: definition.id
        case .custom(let text): text
        case .none: nil
        }
    return definitionSlots(definition).filter(\.template).map { describeSlot($0, prefix: resolved) }
}

private func strings(_ value: JSONValue?, _ path: String, _ what: String, nested: [String] = []) -> [DefinitionIssue] {
    guard let value else { return [] }
    guard let object = value.objectValue else { return [error("invalid-type", path, "must be an object of \(what)")] }
    return object.flatMap { key, item -> [DefinitionIssue] in
        if nested.containsText(key) { return strings(item, "\(path)/\(key)", what) }
        if let text = item.stringValue, !text.isBlankText { return [] }
        return [error("invalid-type", "\(path)/\(pointer(key))", "must be a non-empty string")]
    }
}

func translationErrors(_ definition: FormDefinition) -> [DefinitionIssue] {
    let root = definition.json
    var issues: [DefinitionIssue] = []
    if let lang = root["lang"], lang.stringValue == nil { issues.append(error("invalid-type", "/lang", "\"lang\" must be a string")) }
    issues += strings(root["messages"], "/messages", "message templates") + strings(root["labels"], "/labels", "label templates")
    for text in textNodes(definition) {
        let block = text.node["i18n"]
        let texts = text.kind == .validation ? [] : text.kind.slots
        let unbound = block?.objectValue.map { object in texts.filter { object.has($0) && text.node[$0]?.stringValue == nil } } ?? []
        issues += strings(block, "\(text.path)/i18n", "translation keys", nested: text.kind == .form ? ["messages", "labels"] : [])
        issues += unbound.map {
            error(
                "i18n-unbound-slot", "\(text.path)/i18n/\($0)", "\"\($0)\" has a translation key but no source text",
                "Add \"\($0)\" as the fallback text")
        }
    }
    return issues
}

public func localize(_ input: JSONValue, overlay: JSONValue, lang: String? = nil) throws(FormDefinitionError) -> Localized {
    let parsed = try FormDefinition(json: input)
    let errors = translationErrors(parsed)
    guard errors.isEmpty else { throw FormDefinitionError(issues: errors) }
    var json = JSONValue.object(parsed.json)
    if let lang { json.assign(.string(lang), at: [], key: "lang") }
    for slot in definitionSlots(parsed) {
        guard let text = lookup(overlay, slot.address) else { continue }
        let value = JSONValue.string(slot.kind == .rule ? formatText(text, slot.params) : text)
        if slot.kind == .message || slot.kind == .label, json[slot.location[0]]?.objectValue == nil {
            json.assign(.object(JSONObject()), at: [], key: slot.location[0])
        }
        json.assign(value, at: slot.location[...], key: slot.property)
    }
    let definition = FormDefinition(unchecked: json.objectValue ?? parsed.json)
    return Localized(
        definition: definition, messages: json["messages"] ?? .object(JSONObject()), labels: json["labels"] ?? .object(JSONObject()))
}

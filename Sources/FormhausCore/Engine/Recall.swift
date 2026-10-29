public struct RecallItem: Sendable, Hashable {
    public let group: String
    public let index: Int

    public init(group: String, index: Int) {
        self.group = group
        self.index = index
    }
}

public struct RecallOptions: Sendable {
    public var item: RecallItem?
    public var lang: String?
    public var format: RecallFormatFn?

    public init(item: RecallItem? = nil, lang: String? = nil, format: RecallFormatFn? = nil) {
        self.item = item
        self.lang = lang
        self.format = format
    }
}

typealias KeyResolver = (String) -> String

func substitute(_ definition: FormDefinition, _ text: String, params: JSONObject? = nil, _ resolver: () -> KeyResolver) -> String {
    guard definition.recallsAnswers else { return params.map { formatText(text, $0) } ?? text }
    guard params == nil ? hasRecallBraces(text) : text.utf8.contains(0x7B) else { return text }
    var resolve: KeyResolver?
    return fillTemplate(text) { raw, token in
        switch token {
        case .param(let name): return params?[name].map { jsString($0) } ?? String(raw)
        case .escape: return "{{"
        case .recall(nil): return String(raw)
        case .recall(let key?):
            let resolved = resolve ?? resolver()
            resolve = resolved
            return resolved(key)
        }
    }
}

private func answerText(_ field: FormField, _ item: JSONValue, _ fileName: (String) -> String?) -> RecallAnswer {
    if let entry = item.objectValue { return .text(entry["name"]?.stringValue ?? "") }
    if field.type == "file", let name = item.stringValue.flatMap(fileName) { return .text(name) }
    if let options = field.options, let position = field.optionIndex?.position(of: item), let label = options[position].label {
        return .text(label)
    }
    if case .number(let number) = item { return .number(number) }
    return .text(jsString(item))
}

func recallAnswer(_ field: FormField, _ value: JSONValue?, fileName: (String) -> String?) -> RecallAnswer? {
    guard let value, !value.isNull else { return nil }
    if field.isGroup { return value.arrayValue.map { .number(Double($0.count)) } }
    if booleanTypes.contains(field.type) { return value == .bool(true) ? field.label.map(RecallAnswer.text) : nil }
    guard let items = value.arrayValue else {
        let single = answerText(field, value, fileName)
        if case .text(let text) = single, text.isBlankText { return nil }
        return single
    }
    guard !items.isEmpty else { return nil }
    return .list(
        items.map { item in
            switch answerText(field, item, fileName) {
            case .text(let text): text
            case let other: other.stored
            }
        })
}

struct RecallScope {
    let visibility: VisibilityState
    let values: JSONObject
    var lang: String?
    var format: RecallFormatFn?
    var fileName: (String) -> String? = { _ in nil }
    let active: (String) -> FormField?

    func resolver(_ options: RecallOptions) -> KeyResolver {
        let index = visibility.index
        let group = options.item.flatMap { item in active(item.group).flatMap { $0.isGroup ? $0 : nil } }
        let position = options.item?.index ?? -1
        let items = group.map { itemsOf(values[$0.key]) } ?? []
        let entry = items.indices.contains(position) ? items[position].objectValue : nil
        let scope = entry == nil ? [] : group?.items ?? []
        let shared = scope.isEmpty ? [] : (index.fieldsByKey[group?.key ?? ""] ?? []).filter(\.isGroup).flatMap(\.items)
        let locale = [options.lang, lang, visibility.definition.lang].compactMap { $0 }.first { !$0.isEmpty } ?? "en"
        let format = options.format ?? self.format ?? defaultRecallFormat
        return { key in
            let own = scope.first { sameText($0.key, key) }
            let candidates = own == nil ? index.fieldsByKey[key] ?? [] : shared.filter { sameText($0.key, key) }
            guard !candidates.contains(where: { $0.type == "password" }), let field = own ?? active(key) else { return "" }
            let source = own == nil ? values : entry ?? JSONObject()
            guard source.has(key), let answer = recallAnswer(field, source[key], fileName: fileName) else { return "" }
            return format(answer, field, locale)
        }
    }
}

public func recallText(_ definition: FormDefinition, _ text: String, _ values: JSONObject, options: RecallOptions = RecallOptions())
    -> String
{
    substitute(definition, text) {
        let visibility = VisibilityState(definition)
        return RecallScope(visibility: visibility, values: values) { visibility.activeField($0, values) }.resolver(options)
    }
}

public func recallStatic(_ definition: FormDefinition, _ text: String, group: String? = nil) -> String {
    substitute(definition, text) {
        let fields = definition.allFields
        let scope = fields.first { field in field.isGroup && group.map { sameText(field.key, $0) } == true }?.items ?? []
        return { key in
            guard let field = scope.first(where: { sameText($0.key, key) }) ?? fields.first(where: { sameText($0.key, key) }) else {
                return ""
            }
            return field.label.flatMap { $0.isEmpty ? nil : $0 } ?? key
        }
    }
}

struct ActiveValues {
    var values = JSONObject()
    var active: [(key: String, field: FormField)] = []
    var invalid: [(key: String, value: JSONValue?)] = []
    private var activeByKey = StringMap<FormField>(insertionOrder: true)

    init() {}

    init(values: JSONObject, active: [(key: String, field: FormField)], invalid: [(key: String, value: JSONValue?)]) {
        self.values = values
        self.active = active
        self.invalid = invalid
        for (key, field) in active where !activeByKey.has(key) { activeByKey[key] = field }
    }

    func field(_ key: String) -> FormField? {
        activeByKey[key]
    }
}

func withoutInvalid(
    _ item: JSONObject, _ fields: [FormField], _ resolve: @escaping ResolveMessage, _ report: (String, String) -> Void
) -> JSONObject {
    var entry = item
    for field in fields where item.has(field.key) {
        guard let error = typeError(field, item[field.key], resolve) else { continue }
        report(field.key, error)
        entry.removeValue(forKey: field.key)
    }
    return entry
}

func activeValues(_ visibility: VisibilityState, _ fields: [FormField], _ source: JSONObject, _ resolve: @escaping ResolveMessage)
    -> ActiveValues
{
    var first = StringMap<FormField>(insertionOrder: true)
    for field in fields.reversed() { first[field.key] = field }
    let keys = OrderedKeys(fields.map(\.key)).keys.filter { source.has($0) }
    var result = ActiveValues()
    for _ in 0...fields.count {
        let fieldOf = { (key: String) in result.field(key) ?? first[key] }
        var normalized = JSONObject()
        for key in keys {
            guard let field = fieldOf(key) else { continue }
            if let value = normalizeValue(field, source[key]) { normalized[key] = value }
        }
        var invalid: [(key: String, value: JSONValue?)] = []
        let values = withoutInvalid(normalized, keys.compactMap(fieldOf), resolve) { key, _ in invalid.append((key, normalized[key])) }
        var active: [(key: String, field: FormField)] = []
        for key in keys {
            if let field = visibility.activeField(key, values) { active.append((key, field)) }
        }
        let next = ActiveValues(values: values, active: active, invalid: invalid)
        let settled = keys.allSatisfy { key in next.field(key)?.ordinal == result.field(key)?.ordinal }
        result = next
        if settled { break }
    }
    return result
}

func blankItems(_ resolved: inout ActiveValues, _ resolve: @escaping ResolveMessage) -> [(key: String, error: String)] {
    var errors: [(key: String, error: String)] = []
    for (key, group) in resolved.active where group.isGroup {
        guard let items = resolved.values[key]?.arrayValue else { continue }
        resolved.values[key] = .array(
            items.enumerated().map { index, item in
                guard let entry = item.objectValue else { return item }
                return .object(withoutInvalid(entry, group.items, resolve) { errors.append((itemPath(key, index, $0), $1)) })
            }
        )
    }
    return errors
}

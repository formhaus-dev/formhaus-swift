struct ActiveValues {
    var values = JSONObject()
    var active: [(key: String, field: FormField)] = []

    func field(_ key: String) -> FormField? {
        active.first { sameText($0.key, key) }?.field
    }
}

func activeValues(_ visibility: VisibilityState, _ fields: [FormField], _ source: JSONObject) -> ActiveValues {
    var first = StringMap<FormField>(insertionOrder: true)
    for field in fields.reversed() { first[field.key] = field }
    let keys = OrderedKeys(fields.map(\.key)).keys.filter { source.has($0) }
    var result = ActiveValues()
    for _ in 0...fields.count {
        var values = JSONObject()
        for key in keys {
            guard let field = result.field(key) ?? first[key] else { continue }
            if let value = normalizeValue(field, source[key]) { values[key] = value }
        }
        var active: [(key: String, field: FormField)] = []
        for key in keys {
            if let field = visibility.activeField(key, values) { active.append((key, field)) }
        }
        let settled = keys.allSatisfy { key in
            let next = active.first { sameText($0.key, key) }?.field
            let previous = result.field(key)
            return next?.ordinal == previous?.ordinal
        }
        result = ActiveValues(values: values, active: active)
        if settled { break }
    }
    return result
}

func typeErrors(_ resolved: ActiveValues, _ resolve: @escaping ResolveMessage) -> [(key: String, error: String)] {
    resolved.active.compactMap { key, field in typeError(field, resolved.values[key], resolve).map { (key, $0) } }
}

struct RejectedGroups {
    let resolved: ActiveValues
    let rejected: [(key: String, value: JSONValue?)]
}

func rejectGroups(_ visibility: VisibilityState, _ fields: [FormField], _ input: JSONObject, _ resolve: @escaping ResolveMessage)
    -> RejectedGroups
{
    var source = input
    var rejected: [(key: String, value: JSONValue?)] = []
    func reject(_ keys: [String]) {
        for key in keys {
            rejected.append((key, source[key]))
            source.removeValue(forKey: key)
        }
    }
    func fits(_ key: String) -> Bool {
        fields.contains { sameText($0.key, key) && typeError($0, source[key], resolve) == nil }
    }
    func unchecked(_ key: String) -> Bool {
        fields.contains { sameText($0.key, key) && ($0.isGroup || oversizedList($0, source[key])) }
    }
    reject(OrderedKeys(fields.map(\.key)).keys.filter { source.has($0) && unchecked($0) && !fits($0) })
    let resolved = activeValues(visibility, fields, source)
    let misfits = resolved.active.filter { $0.field.isGroup && typeError($0.field, resolved.values[$0.key], resolve) != nil }
    if misfits.isEmpty { return RejectedGroups(resolved: resolved, rejected: rejected) }
    reject(misfits.map(\.key))
    return RejectedGroups(resolved: activeValues(visibility, fields, source), rejected: rejected)
}

private func strip(_ nodes: JSONValue?, _ invalid: KeySet) -> JSONValue? {
    guard let items = nodes?.arrayValue else { return nodes }
    return .array(
        items.map { item in
            guard var node = item.objectValue else { return item }
            if node["type"]?.stringValue == "section" {
                node["fields"] = strip(node["fields"], invalid)
            } else if let key = node["key"]?.stringValue, invalid.contains(key) {
                node.removeValue(forKey: "validation")
            }
            return .object(node)
        }
    )
}

func withoutRules(_ definition: FormDefinition, _ invalid: KeySet) -> FormDefinition {
    var json = definition.json
    if json["fields"]?.arrayValue != nil { json["fields"] = strip(json["fields"], invalid) }
    if let steps = definition.json["steps"]?.arrayValue {
        json["steps"] = .array(
            steps.map { step in
                guard var object = step.objectValue else { return step }
                object["fields"] = strip(object["fields"], invalid)
                return .object(object)
            }
        )
    }
    return FormDefinition(unchecked: json)
}

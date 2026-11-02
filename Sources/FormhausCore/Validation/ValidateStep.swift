public func validateStep(_ step: FormStep, _ values: JSONObject, options: ValidateOptions = ValidateOptions()) -> FieldErrors {
    validateFields(step.fields, values, options: options)
}

public func validateFields(_ fields: [FormNode], _ values: JSONObject, options: ValidateOptions = ValidateOptions()) -> FieldErrors {
    CallBudget.run {
        validateShown(
            fields, values, values,
            ShownChecks(
                validators: options.validators, messages: options.messages, limits: .standard, previousValues: options.previousValues))
    }
}

func customRules(_ nodes: [FormNode]) -> Bool {
    valueFields(nodes).contains { field in ([field] + field.items).contains { $0.validation?.validator != nil } }
}

struct ShownChecks {
    let validators: Validators
    let messages: MessageSource?
    let limits: ListLimits
    var previousValues: JSONObject?
}

struct ItemSite {
    let group: FormField
    let index: Int
}

func visitShown(
    _ fields: [FormNode], _ values: JSONObject, _ scope: JSONObject, _ limits: ListLimits,
    _ visit: (String, FormField, JSONObject, ItemSite?) -> Void
) {
    for field in shownFields(fields, scope, limits) {
        visit(field.key, field, values, nil)
        guard field.isGroup, typeError(field, values[field.key]) == nil else { continue }
        for (index, item) in itemsOf(values[field.key]).enumerated() {
            let own = itemScope(field, item, values)
            let shown = itemScope(field, item, scope)
            let site = ItemSite(group: field, index: index)
            for rule in field.items where isVisible(rule, shown, limits: limits) {
                visit(itemPath(field.key, index, rule.key), rule, own, site)
            }
        }
    }
}

private func occurrences(_ item: JSONValue, _ key: String) -> [JSONValue] {
    switch item.objectValue?[key] {
    case .array(let values)?: values
    case let value?: [value]
    case nil: []
    }
}

func itemHolds(_ previous: JSONObject?, _ group: FormField, _ items: [JSONValue]) -> [StringMap<JSONValue>] {
    let fields = group.items.filter { ($0.options ?? []).contains { $0.disabled != nil } }
    guard let previous, !fields.isEmpty else { return [] }
    let stored = itemsOf(previous[group.key])
    var counts = fields.map { field -> [JSONValue: Int] in
        let disabled = Set((field.options ?? []).filter { $0.disabled != nil }.compactMap { $0.json["value"] })
        var left: [JSONValue: Int] = [:]
        for item in stored {
            for value in occurrences(item, field.key) where disabled.contains(value) { left[value, default: 0] += 1 }
        }
        return left
    }
    return items.map { item in
        var entry = StringMap<JSONValue>()
        for (position, field) in fields.enumerated() {
            let values = occurrences(item, field.key)
            let kept = values.filter { counts[position][$0, default: 0] > 0 }
            for value in values {
                if let left = counts[position][value], left > 0 { counts[position][value] = left - 1 }
            }
            entry[field.key] = .array(kept)
        }
        return entry
    }
}

func heldValue(_ previous: JSONObject?, _ holds: [StringMap<JSONValue>], _ index: Int, _ key: String) -> JSONValue? {
    if holds.indices.contains(index), let held = holds[index][key] { return held }
    return previous?[key]
}

func validateShown(_ fields: [FormNode], _ values: JSONObject, _ scope: JSONObject, _ checks: ShownChecks) -> FieldErrors {
    var errors = FieldErrors()
    var holds: [Int: [StringMap<JSONValue>]] = [:]
    let previous = checks.previousValues
    visitShown(fields, values, scope, checks.limits) { path, field, own, site in
        var held = previous?[field.key]
        if let site {
            let ordinal = site.group.ordinal
            let found = holds[ordinal] ?? itemHolds(previous, site.group, itemsOf(values[site.group.key]))
            holds[ordinal] = found
            held = heldValue(previous, found, site.index, field.key)
        }
        if let error = fieldValueError(field, own[field.key], own, checks.validators, checks.messages, previous: held) {
            errors[path] = error
        }
    }
    return errors
}

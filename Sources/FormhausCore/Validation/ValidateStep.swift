public func validateStep(
    _ step: FormStep, _ values: JSONObject, validators: [String: ValidatorFn] = [:], messages: MessageSource? = nil
) -> [String: String] {
    validateFields(step.fields, values, validators: validators, messages: messages)
}

public func validateFields(
    _ fields: [FormNode], _ values: JSONObject, validators: [String: ValidatorFn] = [:], messages: MessageSource? = nil
) -> [String: String] {
    validateShown(fields, values, values, validators, messages)
}

func customRules(_ nodes: [FormNode]) -> Bool {
    valueFields(nodes).contains { field in ([field] + field.items).contains { $0.validation?.validator != nil } }
}

private func validateItems(
    _ group: FormField, _ values: JSONObject, _ validators: [String: ValidatorFn], _ messages: MessageSource?, _ scope: JSONObject
) -> [String: String] {
    var errors: [String: String] = [:]
    for (index, item) in itemsOf(values[group.key]).enumerated() {
        let own = itemScope(group, item, values)
        let shown = itemScope(group, item, scope)
        for field in group.items where isVisible(field as Conditional, shown) {
            if let error = validateFieldValue(field, own[field.key], own, validators: validators, messages: messages) {
                errors[itemPath(group.key, index, field.key)] = error
            }
        }
    }
    return errors
}

func validateShown(
    _ fields: [FormNode], _ values: JSONObject, _ scope: JSONObject, _ validators: [String: ValidatorFn], _ messages: MessageSource?
) -> [String: String] {
    var errors: [String: String] = [:]
    for field in shownFields(fields, scope) {
        if let error = validateFieldValue(field, values[field.key], values, validators: validators, messages: messages) {
            errors[field.key] = error
        }
        if field.isGroup {
            errors.merge(validateItems(field, values, validators, messages, scope)) { $1 }
        }
    }
    return errors
}

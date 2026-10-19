public func validateStep(
    _ step: FormStep, _ values: JSONObject, validators: Validators = [:], messages: MessageSource? = nil
) -> FieldErrors {
    validateFields(step.fields, values, validators: validators, messages: messages)
}

public func validateFields(
    _ fields: [FormNode], _ values: JSONObject, validators: Validators = [:], messages: MessageSource? = nil
) -> FieldErrors {
    validateShown(fields, values, values, validators, messages)
}

func customRules(_ nodes: [FormNode]) -> Bool {
    valueFields(nodes).contains { field in ([field] + field.items).contains { $0.validation?.validator != nil } }
}

private func validateItems(
    _ group: FormField, _ values: JSONObject, _ validators: Validators, _ messages: MessageSource?, _ scope: JSONObject
) -> FieldErrors {
    var errors = FieldErrors()
    for (index, item) in itemsOf(values[group.key]).enumerated() {
        let own = itemScope(group, item, values)
        let shown = itemScope(group, item, scope)
        for field in group.items where isVisible(field, shown) {
            if let error = validateFieldValue(field, own[field.key], own, validators: validators, messages: messages) {
                errors[itemPath(group.key, index, field.key)] = error
            }
        }
    }
    return errors
}

func validateShown(
    _ fields: [FormNode], _ values: JSONObject, _ scope: JSONObject, _ validators: Validators, _ messages: MessageSource?
) -> FieldErrors {
    var errors = FieldErrors()
    for field in shownFields(fields, scope) {
        if let error = validateFieldValue(field, values[field.key], values, validators: validators, messages: messages) {
            errors[field.key] = error
        }
        if field.isGroup {
            errors.merge(validateItems(field, values, validators, messages, scope))
        }
    }
    return errors
}

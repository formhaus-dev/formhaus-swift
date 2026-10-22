public func validateStep(_ step: FormStep, _ values: JSONObject, options: ValidateOptions = ValidateOptions()) -> FieldErrors {
    validateFields(step.fields, values, options: options)
}

public func validateFields(_ fields: [FormNode], _ values: JSONObject, options: ValidateOptions = ValidateOptions()) -> FieldErrors {
    CallBudget.run {
        validateShown(fields, values, values, ShownChecks(validators: options.validators, messages: options.messages, limits: .standard))
    }
}

func customRules(_ nodes: [FormNode]) -> Bool {
    valueFields(nodes).contains { field in ([field] + field.items).contains { $0.validation?.validator != nil } }
}

struct ShownChecks {
    let validators: Validators
    let messages: MessageSource?
    let limits: ListLimits

    var options: ValidateOptions { ValidateOptions(validators: validators, messages: messages) }
}

private func validateItems(_ group: FormField, _ values: JSONObject, _ scope: JSONObject, _ checks: ShownChecks) -> FieldErrors {
    var errors = FieldErrors()
    for (index, item) in itemsOf(values[group.key]).enumerated() {
        let own = itemScope(group, item, values)
        let shown = itemScope(group, item, scope)
        for field in group.items where isVisible(field, shown, limits: checks.limits) {
            if let error = validateFieldValue(field, own[field.key], own, options: checks.options) {
                errors[itemPath(group.key, index, field.key)] = error
            }
        }
    }
    return errors
}

func validateShown(_ fields: [FormNode], _ values: JSONObject, _ scope: JSONObject, _ checks: ShownChecks) -> FieldErrors {
    var errors = FieldErrors()
    for field in shownFields(fields, scope, checks.limits) {
        if let error = validateFieldValue(field, values[field.key], values, options: checks.options) {
            errors[field.key] = error
        }
        if field.isGroup, typeError(field, values[field.key]) == nil {
            errors.merge(validateItems(field, values, scope, checks))
        }
    }
    return errors
}

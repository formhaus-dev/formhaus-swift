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

func visitShown(
    _ fields: [FormNode], _ values: JSONObject, _ scope: JSONObject, _ limits: ListLimits,
    _ visit: (String, FormField, JSONObject) -> Void
) {
    for field in shownFields(fields, scope, limits) {
        visit(field.key, field, values)
        guard field.isGroup, typeError(field, values[field.key]) == nil else { continue }
        for (index, item) in itemsOf(values[field.key]).enumerated() {
            let own = itemScope(field, item, values)
            let shown = itemScope(field, item, scope)
            for rule in field.items where isVisible(rule, shown, limits: limits) { visit(itemPath(field.key, index, rule.key), rule, own) }
        }
    }
}

func validateShown(_ fields: [FormNode], _ values: JSONObject, _ scope: JSONObject, _ checks: ShownChecks) -> FieldErrors {
    var errors = FieldErrors()
    visitShown(fields, values, scope, checks.limits) { path, field, own in
        if let error = validateFieldValue(field, own[field.key], own, options: checks.options) { errors[path] = error }
    }
    return errors
}

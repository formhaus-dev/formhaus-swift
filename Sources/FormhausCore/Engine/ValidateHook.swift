extension FormEngine {
    @_spi(Renderer) public var validateWithRules: Bool {
        get { core.validateWithRules }
        set { core.validateWithRules = newValue }
    }

    @_spi(Renderer) public var onValidate: ValidateFn? {
        get { core.onValidate }
        set { core.onValidate = newValue }
    }

    var validatesWithRules: Bool { validateWithRules && onValidate != nil }

    private func validatedNodes(submit: Bool) -> [FormNode] {
        guard submit else { return core.currentStep?.fields ?? [] }
        guard core.isMultiStep else { return definition.fields ?? [] }
        return core.visibleSteps.filter { !core.isStepSkipped($0.id) }.flatMap(\.fields)
    }

    func passesValidate(
        _ validate: ValidateFn, _ values: JSONObject, _ stale: () -> Bool, submit: Bool, ruleErrors: FieldErrors
    ) async throws -> Bool {
        let core = core
        if !ruleErrors.isEmpty { reportRuleErrors() }
        var fields: [String] = []
        let scope = core.visibility.conditionValues(core.values.json)
        visitShown(validatedNodes(submit: submit), core.getSubmitValues(), scope, core.visibility.limits(core.values.json)) { path, _, _ in
            fields.append(path)
        }
        let context = ValidateContext(stepId: core.currentStep?.id, fields: fields, submit: submit)
        let result = try await suspended { try await validate(values, context) }
        if stale() { return false }
        guard let result, !result.isEmpty else { return true }
        let scoped = KeySet(fields)
        var errors = FieldErrors()
        var general: [String] = []
        for (key, message) in result {
            if scoped.contains(key) { errors[key] = message } else { general.append(message) }
        }
        errors.merge(ruleErrors)
        core.applyValidationErrors(errors, formErrors: general, navigate: submit)
        return false
    }
}

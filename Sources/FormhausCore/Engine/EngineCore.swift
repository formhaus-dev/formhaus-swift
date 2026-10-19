final class EngineCore {
    let definition: FormDefinition
    var values: JSONObject
    var errors = FieldErrors()
    var currentStepIndex = 0
    var serverErrors = FieldErrors()
    var skipped: [(id: String, keys: [String])] = []
    let validators: Validators
    let messages: ResolveMessage
    let visibility: VisibilityState

    init(definition: FormDefinition, values initialValues: JSONObject = JSONObject(), options: FormEngineOptions = FormEngineOptions()) {
        self.definition = definition
        validators = options.validators
        messages = messageResolver(options.messages, .catalog(definition.messages ?? .null))
        visibility = VisibilityState(definition)
        let visibility = visibility
        values = createValues(visibility.allFields, initialValues) { visibility.activeField($0, $1) }
        visibility.reconcileHidden(&values, &errors, initial: true)
    }

    var isMultiStep: Bool { definition.isMultiStep }

    var visibleSteps: [FormStep] { visibility.visibleSteps(values) }

    var currentStep: FormStep? {
        guard isMultiStep else { return nil }
        let steps = visibleSteps
        return steps.indices.contains(currentStepIndex) ? steps[currentStepIndex] : steps.last
    }

    var visibleFields: [FormField] {
        let source = isMultiStep ? currentStep?.fields ?? [] : definition.fields ?? []
        return shownFields(source, visibility.scope(values))
    }

    var isFirstStep: Bool { currentStepIndex == 0 }

    var isLastStep: Bool { currentStepIndex >= visibleSteps.count - 1 }

    func isStepSkipped(_ stepId: String) -> Bool {
        skipped.contains { sameText($0.id, stepId) }
    }

    func getSubmitValues() -> JSONObject {
        var result = visibility.conditionValues(values)
        for key in skipped.flatMap(\.keys) { result.removeValue(forKey: key) }
        return result
    }

    func fieldsErrors(_ nodes: [FormNode], _ submitValues: JSONObject? = nil) -> FieldErrors {
        let scope = visibility.conditionValues(values)
        return validateShown(nodes, submitValues ?? getSubmitValues(), scope, validators, .function(messages))
    }

    @discardableResult
    func validate() -> FieldErrors {
        var result = FieldErrors()
        if isMultiStep {
            for step in visibleSteps where !isStepSkipped(step.id) {
                result.merge(fieldsErrors(step.fields))
            }
        } else {
            result = fieldsErrors(definition.fields ?? [])
        }
        errors = serverErrors.merging(result)
        return result
    }

    private func hasStepErrors() -> Bool {
        guard let step = currentStep else { return true }
        let found = fieldsErrors(step.fields)
        if found.isEmpty { return false }
        errors.merge(found)
        return true
    }

    @discardableResult
    func next() -> Bool {
        guard isMultiStep, !isLastStep else { return false }
        includeCurrentStep()
        if hasStepErrors() { return false }
        let target = currentStepIndex + 1
        guard visibleSteps.indices.contains(target) else { return false }
        currentStepIndex = target
        return true
    }
}

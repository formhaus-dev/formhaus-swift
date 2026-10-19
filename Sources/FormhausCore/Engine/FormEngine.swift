public struct FormEngineOptions {
    public var validators: [String: ValidatorFn]
    public var messages: MessageSource?

    public init(validators: [String: ValidatorFn] = [:], messages: MessageSource? = nil) {
        self.validators = validators
        self.messages = messages
    }
}

public final class FormEngine {
    public let definition: FormDefinition
    public internal(set) var values: JSONObject
    public internal(set) var errors: [String: String] = [:]
    public internal(set) var currentStepIndex = 0
    var serverErrors: [String: String] = [:]
    var skipped: [(id: String, keys: [String])] = []
    let validators: [String: ValidatorFn]
    let messages: ResolveMessage
    let visibility: VisibilityState

    public convenience init(definition: JSONValue, values: JSONObject = JSONObject(), options: FormEngineOptions = FormEngineOptions()) throws(FormDefinitionError) {
        self.init(definition: try FormDefinition(json: definition), values: values, options: options)
    }

    public init(definition: FormDefinition, values initialValues: JSONObject = JSONObject(), options: FormEngineOptions = FormEngineOptions()) {
        self.definition = definition
        validators = options.validators
        messages = messageResolver(options.messages, .catalog(definition.messages ?? .null))
        visibility = VisibilityState(definition)
        let visibility = visibility
        values = createValues(visibility.allFields, initialValues) { visibility.activeField($0, $1) }
        visibility.reconcileHidden(&values, &errors, initial: true)
    }

    public var isMultiStep: Bool { definition.isMultiStep }

    public var visibleSteps: [FormStep] { visibility.visibleSteps(values) }

    public var currentStep: FormStep? {
        guard isMultiStep else { return nil }
        let steps = visibleSteps
        return steps.indices.contains(currentStepIndex) ? steps[currentStepIndex] : steps.last
    }

    public var visibleFields: [FormField] {
        let source = isMultiStep ? currentStep?.fields ?? [] : definition.fields ?? []
        return shownFields(source, visibility.scope(values))
    }

    public var isFirstStep: Bool { currentStepIndex == 0 }

    public var isLastStep: Bool { currentStepIndex >= visibleSteps.count - 1 }

    public func isStepSkipped(_ stepId: String) -> Bool {
        skipped.contains { $0.id == stepId }
    }

    public func getSubmitValues() -> JSONObject {
        var result = visibility.conditionValues(values)
        for key in skipped.flatMap(\.keys) { result.removeValue(forKey: key) }
        return result
    }

    func fieldsErrors(_ nodes: [FormNode], _ submitValues: JSONObject? = nil) -> [String: String] {
        let scope = visibility.conditionValues(values)
        return validateShown(nodes, submitValues ?? getSubmitValues(), scope, validators, .function(messages))
    }

    @discardableResult
    public func validate() -> [String: String] {
        var result: [String: String] = [:]
        if isMultiStep {
            for step in visibleSteps where !isStepSkipped(step.id) {
                result.merge(fieldsErrors(step.fields)) { $1 }
            }
        } else {
            result = fieldsErrors(definition.fields ?? [])
        }
        errors = serverErrors.merging(result) { $1 }
        return result
    }

    private func hasStepErrors() -> Bool {
        guard let step = currentStep else { return true }
        let found = fieldsErrors(step.fields)
        if found.isEmpty { return false }
        errors.merge(found) { $1 }
        return true
    }

    @discardableResult
    public func next() -> Bool {
        guard isMultiStep, !isLastStep else { return false }
        includeCurrentStep()
        if hasStepErrors() { return false }
        let target = currentStepIndex + 1
        guard visibleSteps.indices.contains(target) else { return false }
        currentStepIndex = target
        return true
    }
}

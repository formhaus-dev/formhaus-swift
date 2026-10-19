public struct FormEngineOptions: Sendable {
    public var validators: Validators
    public var messages: MessageSource?

    public init(validators: Validators = [:], messages: MessageSource? = nil) {
        self.validators = validators
        self.messages = messages
    }
}

@MainActor
public final class FormEngine {
    let core: EngineCore

    public convenience init(definition: JSONValue, values: JSONObject = JSONObject(), options: FormEngineOptions = FormEngineOptions()) throws(FormDefinitionError) {
        self.init(definition: try FormDefinition(json: definition), values: values, options: options)
    }

    public init(definition: FormDefinition, values: JSONObject = JSONObject(), options: FormEngineOptions = FormEngineOptions()) {
        core = EngineCore(definition: definition, values: values, options: options)
    }

    public var definition: FormDefinition { core.definition }
    public var values: JSONObject { core.values }
    public var errors: FieldErrors { core.errors }
    public var currentStepIndex: Int { core.currentStepIndex }
    public var isMultiStep: Bool { core.isMultiStep }
    public var visibleSteps: [FormStep] { core.visibleSteps }
    public var currentStep: FormStep? { core.currentStep }
    public var visibleFields: [FormField] { core.visibleFields }
    public var isFirstStep: Bool { core.isFirstStep }
    public var isLastStep: Bool { core.isLastStep }

    public func isStepSkipped(_ stepId: String) -> Bool {
        core.isStepSkipped(stepId)
    }

    public func getSubmitValues() -> JSONObject {
        core.getSubmitValues()
    }

    @discardableResult
    public func validate() -> FieldErrors {
        core.validate()
    }

    @discardableResult
    func next() -> Bool {
        core.next()
    }
}

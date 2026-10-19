import os

private let warningLog = Logger(subsystem: "dev.formhaus", category: "definition")

@MainActor
private func reportWarnings(_ definition: FormDefinition, _ options: FormEngineOptions) {
    let issues = checkDefinition(.object(definition.json), options: CheckDefinitionOptions(validators: options.validators.keys))
    for issue in issues {
        if let onWarning = options.onWarning {
            onWarning(issue)
        } else {
            warningLog.warning("[formhaus] \(issue.message, privacy: .public)")
        }
    }
}

@MainActor
final class Listeners {
    private var next = 0
    private var entries: [(id: Int, listener: @MainActor () -> Void)] = []

    func add(_ listener: @escaping @MainActor () -> Void) -> Int {
        next += 1
        entries.append((next, listener))
        return next
    }

    func remove(_ id: Int) {
        entries.removeAll { $0.id == id }
    }

    func fire() {
        var last = 0
        while let entry = entry(after: last) {
            last = entry.id
            entry.listener()
        }
    }

    private func entry(after id: Int) -> (id: Int, listener: @MainActor () -> Void)? {
        var low = 0
        var high = entries.count
        while low < high {
            let middle = (low + high) / 2
            if entries[middle].id <= id { low = middle + 1 } else { high = middle }
        }
        return low < entries.count ? entries[low] : nil
    }
}

@MainActor
public final class FormEngine {
    let core: EngineCore
    let options: FormEngineOptions
    private let listeners = Listeners()

    public convenience init(definition: JSONValue, values: JSONObject = JSONObject(), options: FormEngineOptions = FormEngineOptions())
        throws(FormDefinitionError)
    {
        self.init(definition: try FormDefinition(json: definition), values: values, options: options)
    }

    public init(definition: FormDefinition, values: JSONObject = JSONObject(), options: FormEngineOptions = FormEngineOptions()) {
        self.options = options
        reportWarnings(definition, options)
        core = EngineCore(definition: definition, values: values, validators: options.validators, messages: options.messages)
        if let onFormEvent = options.onFormEvent {
            core.emitEvent = { event in MainActor.assumeIsolated { onFormEvent(event) } }
        }
        let listeners = listeners
        core.onChange = { MainActor.assumeIsolated { listeners.fire() } }
    }

    public var definition: FormDefinition { core.definition }
    public var values: JSONObject { core.values.json }
    public var errors: FieldErrors { core.errors }
    public var currentStepIndex: Int { core.currentStepIndex }
    public var fieldLoading: StringMap<Bool> { core.fieldLoading }
    public var stepValidating: Bool { core.stepValidating }
    public var submitting: Bool { core.submitting }
    public var isMultiStep: Bool { core.isMultiStep }
    public var visibleSteps: [FormStep] { core.visibleSteps }
    public var currentStep: FormStep? { core.currentStep }
    public var visibleFields: [FormField] { core.visibleFields }
    public var visibleNodes: [FormNode] { core.view.visibleNodes }
    public var isFirstStep: Bool { core.isFirstStep }
    public var isLastStep: Bool { core.isLastStep }
    public var canGoNext: Bool { core.canGoNext }

    public var topLevelErrors: [String] {
        let errors = core.errors
        guard !errors.isEmpty else { return core.topLevelErrors }
        let visibility = core.visibility
        let hidden = visibility.allFields.compactMap { field -> String? in
            guard field.type == "hidden", let message = errors[field.key], !message.isEmpty else { return nil }
            let active = visibility.activeField(field.key, core.values.json) ?? field
            return active.ordinal == field.ordinal ? message : nil
        }
        return core.topLevelErrors + hidden
    }

    public var stepErrors: StringMap<[String]> {
        var result = StringMap<[String]>()
        for step in visibleSteps {
            let keys = errorKeys(step.fields, core.errors, core.values.json)
            if !keys.isEmpty { result[step.id] = keys }
        }
        return result
    }

    public var progress: StepProgress {
        let total = visibleSteps.count
        return StepProgress(current: min(currentStepIndex + 1, total), total: total)
    }

    public func subscribe(_ listener: @escaping @MainActor () -> Void) -> @MainActor () -> Void {
        let id = listeners.add(listener)
        let listeners = listeners
        return { listeners.remove(id) }
    }

    public func setValue(_ key: String, _ value: JSONValue?) {
        core.setValue(key, value)
    }

    public func items(_ key: String) -> [GroupItem] {
        core.items(key)
    }

    @discardableResult
    public func addItem(_ key: String) -> Bool {
        core.addItem(key)
    }

    @discardableResult
    public func removeItem(_ key: String, _ index: Int) -> Bool {
        core.removeItem(key, index)
    }

    public func setItemValue(_ key: String, _ index: Int, _ field: String, _ value: JSONValue?) {
        core.setItemValue(key, index, field, value)
    }

    public func setErrors(_ errors: FieldErrors) {
        core.applyValidationErrors(errors, server: true)
    }

    public func setFieldLoading(_ key: String, _ loading: Bool) {
        core.fieldLoading[key] = loading ? true : nil
        core.notify()
    }

    public func cancelPendingActions() {
        core.validationEpoch += 1
        core.operationEpoch += 1
        core.stepValidating = false
        core.submitting = false
        core.notify()
    }

    public func start() {
        core.startEvents()
    }

    public func isStepSkipped(_ stepId: String) -> Bool {
        core.isStepSkipped(stepId)
    }

    @discardableResult
    public func validate() -> FieldErrors {
        core.validate()
    }

    @discardableResult
    public func validateField(_ key: String) -> String? {
        core.validateOne(key)
    }

    public func getSubmitValues() -> JSONObject {
        core.getSubmitValues()
    }

    public func goToStepWithField(_ key: String) {
        guard core.isMultiStep else { return }
        let target = core.visibility.findStepIndex(key, core.values.json, core.currentStepIndex)
        if target == core.currentStepIndex {
            core.notify()
        } else if let target {
            moveTo(target)
        }
    }

    public func reset(_ values: JSONObject? = nil) {
        core.reset(values)
    }

    public func replaceDefinition(_ definition: JSONValue) throws(FormDefinitionError) {
        replaceDefinition(try FormDefinition(json: definition))
    }

    public func replaceDefinition(_ definition: FormDefinition) {
        reportWarnings(definition, options)
        core.replaceDefinition(definition)
    }

    func moveTo(_ index: Int) {
        core.validationEpoch += 1
        core.currentStepIndex = index
        core.notify(structureChanged: true)
    }
}

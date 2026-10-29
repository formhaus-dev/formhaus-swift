final class EngineCore {
    private(set) var definition: FormDefinition
    let validators: Validators
    private let messageSource: MessageSource?
    var locale: [LocaleCatalog] {
        didSet { rebuildMessages() }
    }
    private let missingMessage: MissingMessageFn?
    private(set) var messages: ResolveMessage
    private(set) var visibility: VisibilityState
    var values = Values()
    private(set) var valuesGeneration = 0
    private(set) var errorsGeneration = 0
    private(set) var serverErrorsGeneration = 0
    private(set) var definitionGeneration = 0
    var errors = FieldErrors()
    var serverErrors = FieldErrors()
    var topLevelErrors: [String] = []
    var serverFormErrors: [String] = []
    var currentStepIndex = 0
    var fieldLoading = StringMap<Bool>()
    var stepValidating = false
    var validateWithRules = false
    var onValidate: ValidateFn?
    var reportedErrors: (operation: Int, generation: Int, errors: FieldErrors)?
    var submitting = false
    var skipped: [(id: String, keys: [String])] = []
    var validationEpoch = 0
    var operationEpoch = 0
    var restarts = 0
    var latestOperation = 0
    var sending: Int?
    var started = false
    var viewedStep: String?
    var shownFields: ShownFields?
    var domIds: (generation: Int, ids: DomIds)?
    private(set) var version = 0
    var keptCache: (version: Int, generation: Int, values: JSONObject)?
    var emitEvent: ((FormEvent) -> Void)?
    var onChange: (() -> Void)?

    init(
        definition: FormDefinition, values initialValues: JSONObject = JSONObject(), validators: Validators = [:],
        messages: MessageSource? = nil, locale: [LocaleCatalog] = [], keep: Bool = false, missingMessage: MissingMessageFn? = nil
    ) {
        self.definition = definition
        self.validators = validators
        messageSource = messages
        self.locale = locale
        self.missingMessage = missingMessage
        self.messages = watchedResolver(messages, definition, locale, missingMessage)
        visibility = VisibilityState(definition, keep: keep)
        values = Self.startValues(visibility, Values(fresh: initialValues), &errors)
    }

    private func rebuildMessages() {
        messages = watchedResolver(messageSource, definition, locale, missingMessage)
    }

    private static func startValues(_ visibility: VisibilityState, _ initialValues: Values, _ errors: inout FieldErrors) -> Values {
        var values = createValues(visibility.allFields, initialValues) { visibility.activeField($0, $1) }
        visibility.reconcileHidden(&values, &errors, initial: true)
        return values
    }

    func load(_ next: FormDefinition, _ initialValues: Values) {
        definition = next
        definitionGeneration += 1
        rebuildMessages()
        visibility = VisibilityState(next, keep: visibility.keep)
        replaceValues(Self.startValues(visibility, initialValues, &errors))
    }

    func replaceValues(_ next: Values) {
        values = next
        valuesGeneration += 1
    }

    func replaceErrors(_ next: FieldErrors) {
        errors = next
        errorsGeneration += 1
    }

    func replaceServerErrors(_ next: FieldErrors) {
        serverErrors = next
        serverErrorsGeneration += 1
    }

    @discardableResult
    func reconcileHidden(initial: Bool = false, written: String? = nil) -> KeySet {
        visibility.reconcileHidden(&values, &errors, initial: initial, written: written)
    }

    var isMultiStep: Bool { definition.isMultiStep }

    var view: VisibilityView { visibility.state(values.json, currentStepIndex) }

    var visibleSteps: [FormStep] { view.visibleSteps }

    var currentStep: FormStep? { view.currentStep }

    var visibleFields: [FormField] { view.visibleFields }

    var isFirstStep: Bool { currentStepIndex == 0 }

    var isLastStep: Bool { currentStepIndex >= visibleSteps.count - 1 }

    var canGoNext: Bool { visibility.canGoNext(values.json, currentStepIndex, validators) }

    func isStepSkipped(_ stepId: String) -> Bool {
        skipped.contains { sameText($0.id, stepId) }
    }

    func markSkipped(_ stepId: String, _ keys: [String]) {
        if let position = skipped.firstIndex(where: { sameText($0.id, stepId) }) {
            skipped[position].keys = keys
        } else {
            skipped.append((stepId, keys))
        }
    }

    func unmarkSkipped(_ stepId: String) {
        skipped.removeAll { sameText($0.id, stepId) }
    }

    func notify(structureChanged: Bool = false, valuesChanged: Bool = false) {
        visibility.markChanged(structureChanged, valuesChanged)
        version += 1
        onChange?()
        trackChanges(fields: valuesChanged)
    }

    func emit(_ event: FormEvent) {
        emitEvent?(event)
    }

    func baselineFields() {
        if emitEvent == nil {
            shownFields = nil
        } else if started, shownFields == nil {
            shownFields = visibility.trackShown(values, since: nil).state
        }
    }

    func startEvents() {
        guard !started else { return }
        emit(.formViewed)
        started = true
        viewedStep = nil
        trackChanges(fields: true)
    }

    func trackChanges(fields: Bool) {
        guard started else { return }
        if fields && emitEvent != nil { trackFields() }
        if let step = currentStep, viewedStep.map({ !sameText($0, step.id) }) ?? true {
            viewedStep = step.id
            emit(.stepViewed(stepId: step.id, stepIndex: currentStepIndex))
        }
    }

    private func trackFields() {
        let (next, flips) = visibility.trackShown(values, since: shownFields)
        shownFields = next
        for (key, shown) in flips {
            emit(shown ? .fieldShown(fieldKey: key) : .fieldHidden(fieldKey: key))
        }
    }
}

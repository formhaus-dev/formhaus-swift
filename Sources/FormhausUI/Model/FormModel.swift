@_spi(Renderer) import FormhausCore
import Observation

@MainActor
@Observable
public final class FormModel {
    public let engine: FormEngine
    public let options: FormRendererOptions
    @ObservationIgnored let submitHandler: SubmitHandler

    public private(set) var structure: FormStructure
    public private(set) var stepValidating = false
    public private(set) var submitting = false
    public private(set) var topLevelErrors: [String] = []
    public private(set) var errorEntries: [ErrorEntry] = []
    public private(set) var stepErrorCounts: [String: Int] = [:]
    public private(set) var actions: FormActionsState
    public private(set) var actionError: String?
    public private(set) var invalidAttempts = 0
    public private(set) var focusRequest: FocusRequest?
    public private(set) var version = 0
    public private(set) var structureVersion = 0
    public private(set) var valuesVersion = 0
    public var loading = false {
        didSet { if oldValue != loading { refreshDisabled() } }
    }
    public private(set) var disabled = false

    @ObservationIgnored private var fieldStates: [String: FieldState] = [:]
    @ObservationIgnored private var groupStates: [String: GroupState] = [:]
    @ObservationIgnored var optionStates: [String: OptionsState] = [:]
    @ObservationIgnored private var lastValues: JSONObject
    @ObservationIgnored private var lastErrors: FieldErrors
    @ObservationIgnored private var focusCounter = 0
    @ObservationIgnored private var emittedValues: JSONObject?

    public init(engine: FormEngine, options: FormRendererOptions = FormRendererOptions(), onSubmit: @escaping SubmitHandler) {
        self.engine = engine
        self.options = options
        submitHandler = onSubmit
        structure = FormStructure(engine)
        actions = engine.actionsState(options.labels)
        lastValues = engine.values
        lastErrors = engine.errors
        refreshStatus()
        _ = engine.subscribe { [weak self] in self?.refresh() }
    }

    public convenience init(
        definition: FormDefinition, initialValues: JSONObject = JSONObject(), engineOptions: FormEngineOptions = FormEngineOptions(),
        options: FormRendererOptions = FormRendererOptions(), onSubmit: @escaping SubmitHandler
    ) {
        let engine = FormEngine(definition: definition, values: initialValues, options: engineOptions)
        self.init(engine: engine, options: options, onSubmit: onSubmit)
    }

    public var definition: FormDefinition { engine.definition }

    public func field(_ key: String) -> FieldState {
        if let state = fieldStates[key] { return state }
        let state = FieldState(key: key)
        fieldStates[key] = state
        refreshField(state)
        return state
    }

    public func group(_ key: String) -> GroupState {
        if let state = groupStates[key] { return state }
        let state = GroupState(key: key)
        groupStates[key] = state
        state.update(engine.items(key))
        return state
    }

    public func label(_ key: String, _ params: JSONObject = JSONObject()) -> String {
        engine.label(key, options.labels, params)
    }

    public func start() {
        engine.start()
        reloadOptions()
        emitValues()
    }

    func requestFocus(_ key: String?) {
        focusCounter += 1
        focusRequest = FocusRequest(key: key, id: focusCounter)
    }

    func noteInvalidAttempt() {
        invalidAttempts += 1
        requestFocus(engine.firstErrorKey())
    }

    func setActionError(_ message: String?) {
        if actionError != message { actionError = message }
    }

    private func refresh() {
        version = engine.version
        let previousStep = structure.currentStep?.nodeID
        let nextStructure = FormStructure(engine)
        let structureChanged = nextStructure != structure
        if structureChanged {
            structure = nextStructure
            structureVersion += 1
        }
        let values = engine.values
        let valuesChanged = values != lastValues
        lastValues = values
        if valuesChanged { valuesVersion += 1 }
        for state in fieldStates.values { refreshField(state) }
        for state in groupStates.values { state.update(engine.items(state.key)) }
        refreshStatus()
        if previousStep != structure.currentStep?.nodeID { requestFocus(engine.firstErrorKey()) }
        if valuesChanged || structureChanged { reloadOptions() }
        if valuesChanged { emitValues() }
    }

    private func refreshField(_ state: FieldState) {
        let key = state.key
        state.update(value: engine.value(at: key), error: engine.errors[key], loading: engine.fieldLoading[key] == true)
    }

    private func refreshStatus() {
        assign(\.stepValidating, engine.stepValidating)
        assign(\.submitting, engine.submitting)
        assign(\.topLevelErrors, engine.topLevelErrors)
        assign(\.actions, engine.actionsState(options.labels))
        let errors = engine.errors
        if errors != lastErrors || errorEntries.isEmpty != errors.isEmpty || structureVersion != lastStructureVersion {
            lastErrors = errors
            lastStructureVersion = structureVersion
            assign(\.errorEntries, engine.errorEntries(options.labels))
            assign(\.stepErrorCounts, engine.stepErrors.reduce(into: [:]) { $0[$1.key] = $1.value.count })
        }
        refreshDisabled()
    }

    @ObservationIgnored private var lastStructureVersion = -1

    private func refreshDisabled() {
        assign(\.disabled, loading || engine.stepValidating || engine.submitting)
    }

    private func assign<Value: Equatable>(_ path: ReferenceWritableKeyPath<FormModel, Value>, _ value: Value) {
        if self[keyPath: path] != value { self[keyPath: path] = value }
    }

    private func emitValues() {
        guard let onValuesChange = options.onValuesChange else { return }
        let values = engine.values
        guard values != emittedValues else { return }
        emittedValues = values
        onValuesChange(values)
    }
}

@_spi(Renderer) import FormhausCore
import Observation

@MainActor
@Observable
public final class FormModel {
    public let engine: FormEngine
    @ObservationIgnored public private(set) var options: FormRendererOptions
    @ObservationIgnored private(set) var submitHandler: SubmitHandler
    @ObservationIgnored private var hooks: HookBox?
    @ObservationIgnored private nonisolated(unsafe) var unsubscribe: (@MainActor () -> Void)?

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
    private(set) var alertVersion = 0
    @ObservationIgnored private var seenErrors = -1

    @ObservationIgnored private var fieldStates: [String: FieldState] = [:]
    @ObservationIgnored private var groupStates: [String: GroupState] = [:]
    @ObservationIgnored var optionStates: [String: OptionsState] = [:]
    @ObservationIgnored private var lastValues: JSONObject
    @ObservationIgnored private var lastErrors: FieldErrors
    @ObservationIgnored private var focusCounter = 0
    @ObservationIgnored private var pendingFocusKey: String?
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
        unsubscribe = engine.subscribe { [weak self] in self?.refresh() }
    }

    deinit {
        let owner = ObjectIdentifier(self)
        let unsubscribe = unsubscribe
        Task { @MainActor in
            unsubscribe?()
            UploadStore.release(owner: owner)
        }
    }

    public convenience init(
        definition: FormDefinition, initialValues: JSONObject = JSONObject(), engineOptions: FormEngineOptions = FormEngineOptions(),
        options: FormRendererOptions = FormRendererOptions(), onSubmit: @escaping SubmitHandler
    ) {
        let hooks = HookBox(engineOptions)
        let engine = FormEngine(definition: definition, values: initialValues, options: hooks.forwarding())
        self.init(engine: engine, options: options, onSubmit: onSubmit)
        self.hooks = hooks
    }

    func updateHandlers(
        engineOptions: FormEngineOptions? = nil, options: FormRendererOptions? = nil, onSubmit: SubmitHandler? = nil
    ) {
        if let engineOptions { hooks?.current = engineOptions }
        if let options { self.options = options }
        if let onSubmit { submitHandler = onSubmit }
    }

    public convenience init(
        localized: Localized, initialValues: JSONObject = JSONObject(), engineOptions: FormEngineOptions = FormEngineOptions(),
        options: FormRendererOptions = FormRendererOptions(), onSubmit: @escaping SubmitHandler
    ) {
        var engineOptions = engineOptions
        if engineOptions.messages == nil { engineOptions.messages = .catalog(localized.messages) }
        var options = options
        if options.labels == nil { options.labels = .catalog(localized.labels) }
        self.init(
            definition: localized.definition, initialValues: initialValues, engineOptions: engineOptions, options: options,
            onSubmit: onSubmit)
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
        refreshGroup(state)
        return state
    }

    public func text(forLabel key: String, _ params: JSONObject = JSONObject()) -> String {
        let text = engine.label(key, options.labels, params)
        guard text.isEmpty, let fallback = upcomingLabels[key] else { return text }
        return formatTemplate(fallback, params)
    }

    public func start() {
        engine.start()
        reloadOptions()
        emitValues()
    }

    func requestFocus(_ key: String?) {
        focusCounter += 1
        focusRequest = FocusRequest(key: key, id: focusCounter)
        if let previous = pendingFocusKey, previous != key { fieldStates[previous]?.dropFocusRequest() }
        pendingFocusKey = key
        if let key { field(key).requestFocus(focusCounter) }
    }

    func dropFocusRequest() {
        guard focusRequest != nil else { return }
        focusRequest = nil
        if let previous = pendingFocusKey { fieldStates[previous]?.dropFocusRequest() }
        pendingFocusKey = nil
    }

    func noteInvalidAttempt() {
        invalidAttempts += 1
        requestFocus(engine.firstErrorKey())
    }

    func setActionError(_ message: String?) {
        if actionError != message { actionError = message }
        if message != nil { alertVersion += 1 }
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
        for state in groupStates.values { refreshGroup(state) }
        refreshStatus()
        if previousStep != structure.currentStep?.nodeID { requestFocus(engine.firstErrorKey()) }
        if valuesChanged || structureChanged { reloadOptions() }
        if valuesChanged {
            emitValues()
            pruneUploads(values)
        }
    }

    private func pruneUploads(_ values: JSONObject) {
        let files = Set(values.compactMap { $0.value.stringValue }.filter { $0.hasPrefix("file:") })
        UploadStore.prune(owner: ObjectIdentifier(self), keeping: files)
    }

    private func refreshGroup(_ state: GroupState) {
        let items = engine.items(state.key)
        state.update(items, hasContent: items.indices.map { engine.itemHasContent(state.key, $0) })
    }

    private func refreshField(_ state: FieldState) {
        let key = state.key
        state.update(value: engine.value(at: key), error: engine.errors[key], loading: engine.fieldLoading[key] == true)
    }

    private func refreshStatus() {
        assign(\.stepValidating, engine.stepValidating)
        assign(\.submitting, engine.submitting)
        assign(\.topLevelErrors, engine.topLevelErrors)
        if engine.errorsVersion != seenErrors {
            seenErrors = engine.errorsVersion
            if !topLevelErrors.isEmpty { alertVersion += 1 }
        }
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

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
    public private(set) var errorGroups: [ErrorGroup] = []
    public private(set) var stepErrorCounts: [String: Int] = [:]
    public private(set) var actions: FormActionsState
    public private(set) var actionError: String?
    public private(set) var invalidAttempts = 0
    public private(set) var focusRequest: FocusRequest?
    public private(set) var version = 0
    public private(set) var structureVersion = 0
    public private(set) var valuesVersion = 0
    public var loading = false {
        didSet { if oldValue != loading { loadingChanged() } }
    }
    public private(set) var disabled = false
    private(set) var alertVersion = 0
    @ObservationIgnored private var seenErrors = -1

    @ObservationIgnored private(set) var fieldStates: [String: FieldState] = [:]
    @ObservationIgnored private var groupStates: [String: GroupState] = [:]
    @ObservationIgnored var optionStates: [String: OptionsState] = [:]
    @ObservationIgnored var optionsRevision = -1
    #if os(iOS)
        @ObservationIgnored var inNavigationBar = false
    #endif
    @ObservationIgnored private var lastValues: JSONObject
    @ObservationIgnored var lastRestarts = 0
    @ObservationIgnored private var lastErrors: FieldErrors
    @ObservationIgnored private var focusCounter = 0
    @ObservationIgnored private var pendingFocusKey: String?
    @ObservationIgnored var emittedValues: JSONObject?
    @ObservationIgnored var heldEdits: [String: JSONValue?] = [:]
    let snapshots = SnapshotState()

    public init(engine: FormEngine, options: FormRendererOptions = FormRendererOptions(), onSubmit: @escaping SubmitHandler) {
        self.engine = engine
        self.options = options
        submitHandler = onSubmit
        structure = FormStructure(engine)
        actions = engine.actionsState(options.labels)
        lastValues = engine.values
        lastErrors = engine.errors
        if adoptRestoredUploads() {
            structure = FormStructure(engine)
            lastValues = engine.values
        }
        snapshots.last = engine.snapshot()
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
        options: FormRendererOptions = FormRendererOptions(), restoring snapshot: FormSnapshot? = nil, onSubmit: @escaping SubmitHandler
    ) {
        let hooks = HookBox(engineOptions.recalling(with: options))
        let engine = FormEngine(definition: definition, values: initialValues, options: hooks.forwarding(), restoring: snapshot)
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
        options: FormRendererOptions = FormRendererOptions(), restoring snapshot: FormSnapshot? = nil, onSubmit: @escaping SubmitHandler
    ) {
        var engineOptions = engineOptions
        if engineOptions.messages == nil { engineOptions.messages = .catalog(localized.messages) }
        var options = options
        if options.labels == nil { options.labels = .catalog(localized.labels) }
        self.init(
            definition: localized.definition, initialValues: initialValues, engineOptions: engineOptions, options: options,
            restoring: snapshot, onSubmit: onSubmit)
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

    func errorText(forKey key: String) -> String? {
        errorGroups.lazy.flatMap(\.entries).first { $0.key == key }?.text
    }

    public func start() {
        engine.start()
        reloadOptions()
        emitValues()
    }

    func requestFocus(_ key: String?, afterErrors: Bool = false) {
        focusCounter += 1
        let summary = afterErrors && key != nil && errorGroups.lazy.flatMap(\.entries).dropFirst().first != nil
        focusRequest = FocusRequest(key: key, id: focusCounter, summary: summary)
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
        requestFocus(engine.firstErrorKey(), afterErrors: true)
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
        if previousStep != structure.currentStep?.nodeID { requestFocus(engine.firstErrorKey(), afterErrors: true) }
        if valuesChanged || structureChanged { reloadOptions() }
        if valuesChanged { emitValues() }
        snapshotChanged()
        pruneUploadsAfterRestart(values)
    }

    private func refreshGroup(_ state: GroupState) {
        let items = engine.items(state.key)
        state.update(items, hasContent: items.isEmpty ? [] : engine.itemsHaveContent(state.key))
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
        let recallChanged = !errors.isEmpty && valuesVersion != lastValuesVersion
        if errors != lastErrors || errorGroups.isEmpty != errors.isEmpty || structureVersion != lastStructureVersion || recallChanged {
            lastErrors = errors
            lastStructureVersion = structureVersion
            lastValuesVersion = valuesVersion
            assign(\.errorGroups, engine.errorGroups(options.labels))
            assign(\.stepErrorCounts, engine.stepErrors.reduce(into: [:]) { $0[$1.key] = $1.value.count })
        }
        refreshDisabled()
    }

    @ObservationIgnored private var lastStructureVersion = -1
    @ObservationIgnored private var lastValuesVersion = -1

    func refreshDisabled() {
        assign(\.disabled, loading || engine.stepValidating || engine.submitting)
    }

    private func assign<Value: Equatable>(_ path: ReferenceWritableKeyPath<FormModel, Value>, _ value: Value) {
        if self[keyPath: path] != value { self[keyPath: path] = value }
    }
}

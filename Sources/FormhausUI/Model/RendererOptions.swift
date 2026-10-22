@_spi(Renderer) import FormhausCore

public typealias OptionsProvider = @MainActor @Sendable (JSONObject) async -> [FieldOption]
public typealias FieldChangeFn = @MainActor (String, JSONValue?, JSONObject) -> Void
public typealias ValuesChangeFn = @MainActor (JSONObject) -> Void
public typealias ActionErrorFn = @MainActor (any Error) -> Void

public struct FormRendererOptions {
    public var labels: LabelSource?
    public var optionsProviders: [String: OptionsProvider]
    public var onCancel: (@MainActor () -> Void)?
    public var onFieldChange: FieldChangeFn?
    public var onValuesChange: ValuesChangeFn?
    public var onError: ActionErrorFn?
    public var lang: String?
    public var formatRecall: RecallFormatFn?
    public var testIds: TestIds

    public init(
        labels: LabelSource? = nil, optionsProviders: [String: OptionsProvider] = [:], onCancel: (@MainActor () -> Void)? = nil,
        onFieldChange: FieldChangeFn? = nil, onValuesChange: ValuesChangeFn? = nil, onError: ActionErrorFn? = nil,
        lang: String? = nil, formatRecall: RecallFormatFn? = nil, testIds: TestIds = .automatic
    ) {
        self.labels = labels
        self.optionsProviders = optionsProviders
        self.onCancel = onCancel
        self.onFieldChange = onFieldChange
        self.onValuesChange = onValuesChange
        self.onError = onError
        self.lang = lang
        self.formatRecall = formatRecall
        self.testIds = testIds
    }
}

extension FormEngineOptions {
    func recalling(with renderer: FormRendererOptions) -> FormEngineOptions {
        var options = self
        options.lang = lang ?? renderer.lang
        options.formatRecall = formatRecall ?? renderer.formatRecall
        return options
    }
}

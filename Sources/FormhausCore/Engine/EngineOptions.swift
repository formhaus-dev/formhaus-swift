public enum StepChangeReason: String, Sendable {
    case next
    case back
    case autoAdvance
    case skip
}

public struct StepChangeContext: Sendable {
    public let fromStepId: String
    public let toStepId: String
    public let reason: StepChangeReason
    public let values: JSONObject
}

public enum SubmitResult: Sendable, Equatable {
    case ok
    case rejected(errors: FieldErrors = [:], formErrors: [String] = [])

    public init?(json: JSONValue?) {
        guard let object = json?.objectValue else { return nil }
        guard object["ok"] == .bool(false) else {
            self = .ok
            return
        }
        var errors = FieldErrors()
        for (key, value) in object["errors"]?.objectValue ?? JSONObject() {
            if let items = value.arrayValue {
                errors[key] = items.map { $0.isNull ? "" : jsString($0) }.joined(separator: " ")
            } else if let message = value.stringValue {
                errors[key] = message
            }
        }
        let formErrors = object["formErrors"]?.arrayValue?.compactMap(\.stringValue) ?? []
        self = .rejected(errors: errors, formErrors: formErrors)
    }

    var isRejection: Bool {
        if case .rejected = self { return true }
        return false
    }
}

public struct StepProgress: Sendable, Hashable {
    public let current: Int
    public let total: Int
}

public struct GroupItem: Sendable {
    public let id: String
    public let fields: [FormField]
}

public enum SubmitFailureReason: String, Sendable {
    case rejected
    case error
}

public enum FormEvent: Sendable, Equatable {
    case formViewed
    case stepViewed(stepId: String, stepIndex: Int)
    case fieldError(fieldKey: String, error: String)
    case fieldShown(fieldKey: String)
    case fieldHidden(fieldKey: String)
    case stepCompleted(stepId: String)
    case stepSkipped(stepId: String)
    case formSubmitted(fieldCount: Int)
    case formSubmitSucceeded
    case formSubmitFailed(reason: SubmitFailureReason)
    case formReset

    public var type: String {
        switch self {
        case .formViewed: "form_viewed"
        case .stepViewed: "step_viewed"
        case .fieldError: "field_error"
        case .fieldShown: "field_shown"
        case .fieldHidden: "field_hidden"
        case .stepCompleted: "step_completed"
        case .stepSkipped: "step_skipped"
        case .formSubmitted: "form_submitted"
        case .formSubmitSucceeded: "form_submit_succeeded"
        case .formSubmitFailed: "form_submit_failed"
        case .formReset: "form_reset"
        }
    }
}

public struct FormLifecycleError: Error, CustomStringConvertible {
    public enum Phase: String, Sendable {
        case afterStepChange
        case afterSubmit
    }

    public let phase: Phase
    public let cause: any Error
    public let committed = true

    public var message: String {
        "The action completed, but \(phase.rawValue) failed: \(String(describing: cause))"
    }

    public var description: String { message }
}

public typealias StepValidateFn = @MainActor @Sendable (String, JSONObject) async throws -> FieldErrors?
public typealias BeforeStepChangeFn = @MainActor @Sendable (StepChangeContext) async throws -> Bool?
public typealias AfterStepChangeFn = @MainActor @Sendable (StepChangeContext) async throws -> Void
public typealias BeforeSubmitFn = @MainActor @Sendable (JSONObject) async throws -> Bool?
public typealias SubmitFn = @MainActor @Sendable (JSONObject, [String]) async throws -> Void
public typealias SubmitHandler = @MainActor @Sendable (JSONObject, [String]) async throws -> SubmitResult?
public typealias FormEventFn = @MainActor @Sendable (FormEvent) -> Void
public typealias WarningFn = @MainActor @Sendable (DefinitionIssue) -> Void

public struct FormEngineOptions: Sendable {
    public var onBeforeStepChange: BeforeStepChangeFn?
    public var onAfterStepChange: AfterStepChangeFn?
    public var onBeforeSubmit: BeforeSubmitFn?
    public var onAfterSubmit: SubmitFn?
    public var onStepValidate: StepValidateFn?
    public var onFormEvent: FormEventFn?
    public var onWarning: WarningFn?
    public var validators: Validators
    public var messages: MessageSource?

    public init(
        onBeforeStepChange: BeforeStepChangeFn? = nil, onAfterStepChange: AfterStepChangeFn? = nil,
        onBeforeSubmit: BeforeSubmitFn? = nil, onAfterSubmit: SubmitFn? = nil, onStepValidate: StepValidateFn? = nil,
        onFormEvent: FormEventFn? = nil, onWarning: WarningFn? = nil, validators: Validators = [:], messages: MessageSource? = nil
    ) {
        self.onBeforeStepChange = onBeforeStepChange
        self.onAfterStepChange = onAfterStepChange
        self.onBeforeSubmit = onBeforeSubmit
        self.onAfterSubmit = onAfterSubmit
        self.onStepValidate = onStepValidate
        self.onFormEvent = onFormEvent
        self.onWarning = onWarning
        self.validators = validators
        self.messages = messages
    }
}

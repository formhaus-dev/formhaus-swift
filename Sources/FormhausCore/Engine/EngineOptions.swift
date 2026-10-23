import Foundation

func errorMessage(_ error: any Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? (error as NSError).localizedDescription
}

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

public struct GroupItem: Sendable, Identifiable, Hashable {
    public let id: String
    public let fields: [FormField]

    public static func == (lhs: GroupItem, rhs: GroupItem) -> Bool {
        lhs.id == rhs.id && lhs.fields.count == rhs.fields.count && zip(lhs.fields, rhs.fields).allSatisfy { $0.ordinal == $1.ordinal }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(fields.map(\.ordinal))
    }
}

public enum SubmitFailureReason: Sendable, Equatable {
    case validation
    case rejected
    case error(status: Int?)

    public var name: String {
        switch self {
        case .validation: "validation"
        case .rejected: "rejected"
        case .error: "error"
        }
    }
}

public protocol SubmitStatusError: Error {
    var status: Int? { get }
}

func submitStatus(_ error: any Error) -> Int? {
    if let error = error as? any SubmitStatusError { return error.status }
    return error is URLError ? 0 : nil
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
    case stepRedirected(requestedStepId: String, stepId: String?, reason: StepRedirectReason)
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
        case .stepRedirected: "step_redirected"
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
        "The action completed, but \(phase.rawValue) failed: \(errorMessage(cause))"
    }

    public var description: String { message }
}

public struct ValidateContext: Sendable, Hashable {
    public let stepId: String?
    public let fields: [String]
    public let submit: Bool
}

public typealias StepValidateFn = @MainActor @Sendable (String, JSONObject) async throws -> FieldErrors?
public typealias ValidateFn = @MainActor @Sendable (JSONObject, ValidateContext) async throws -> FieldErrors?
public typealias BeforeStepChangeFn = @MainActor @Sendable (StepChangeContext) async throws -> Bool?
public typealias AfterStepChangeFn = @MainActor @Sendable (StepChangeContext) async throws -> Void
public typealias BeforeSubmitFn = @MainActor @Sendable (JSONObject) async throws -> Bool?
public typealias AfterSubmitFn = @MainActor @Sendable (JSONObject, [String]) async throws -> Void
public typealias SubmitHandler = @MainActor @Sendable (JSONObject, [String]) async throws -> SubmitResult?
public typealias FormEventFn = @MainActor @Sendable (FormEvent) -> Void
public typealias WarningFn = @MainActor @Sendable (DefinitionIssue) -> Void

public protocol FormResearch: Sendable {
    func seed() -> String
    func order(seed: String, key: String, options: [FieldOption]) -> [FieldOption]
}

public enum HiddenValues: String, Sendable {
    case clear
    case keep
}

public struct FormEngineOptions: Sendable {
    public var onBeforeStepChange: BeforeStepChangeFn?
    public var onAfterStepChange: AfterStepChangeFn?
    public var onBeforeSubmit: BeforeSubmitFn?
    public var onAfterSubmit: AfterSubmitFn?
    public var onStepValidate: StepValidateFn?
    public var onValidate: ValidateFn?
    public var onFormEvent: FormEventFn?
    public var onWarning: WarningFn?
    public var validators: Validators
    public var messages: MessageSource?
    public var locale: [LocaleCatalog]
    public var lang: String?
    public var formatRecall: RecallFormatFn?
    public var seed: String?
    public var research: (any FormResearch)?
    public var hiddenValues: HiddenValues

    public init(
        onBeforeStepChange: BeforeStepChangeFn? = nil, onAfterStepChange: AfterStepChangeFn? = nil,
        onBeforeSubmit: BeforeSubmitFn? = nil, onAfterSubmit: AfterSubmitFn? = nil, onStepValidate: StepValidateFn? = nil,
        onValidate: ValidateFn? = nil, onFormEvent: FormEventFn? = nil, onWarning: WarningFn? = nil, validators: Validators = [:],
        messages: MessageSource? = nil, locale: [LocaleCatalog] = [], lang: String? = nil, formatRecall: RecallFormatFn? = nil,
        seed: String? = nil, research: (any FormResearch)? = nil, hiddenValues: HiddenValues = .clear
    ) {
        self.onBeforeStepChange = onBeforeStepChange
        self.onAfterStepChange = onAfterStepChange
        self.onBeforeSubmit = onBeforeSubmit
        self.onAfterSubmit = onAfterSubmit
        self.onStepValidate = onStepValidate
        self.onValidate = onValidate
        self.onFormEvent = onFormEvent
        self.onWarning = onWarning
        self.validators = validators
        self.messages = messages
        self.locale = locale
        self.lang = lang
        self.formatRecall = formatRecall
        self.seed = seed
        self.research = research
        self.hiddenValues = hiddenValues
    }
}

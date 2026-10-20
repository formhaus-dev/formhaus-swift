public struct IssueCode: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }

    public var description: String { rawValue }

    public static func == (lhs: IssueCode, rhs: IssueCode) -> Bool {
        sameText(lhs.rawValue, rhs.rawValue)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(JSKey(rawValue))
    }
}

extension IssueCode {
    public static let invalidType = IssueCode(rawValue: "invalid-type")
    public static let missingProperty = IssueCode(rawValue: "missing-property")
    public static let unknownProperty = IssueCode(rawValue: "unknown-property")
    public static let emptyLabel = IssueCode(rawValue: "empty-label")
    public static let fieldsAndSteps = IssueCode(rawValue: "fields-and-steps")
    public static let duplicateStepId = IssueCode(rawValue: "duplicate-step-id")
    public static let duplicateKey = IssueCode(rawValue: "duplicate-key")
    public static let duplicateOptionValue = IssueCode(rawValue: "duplicate-option-value")
    public static let reservedKey = IssueCode(rawValue: "reserved-key")
    public static let routeTarget = IssueCode(rawValue: "route-target")
    public static let unknownField = IssueCode(rawValue: "unknown-field")
    public static let groupScope = IssueCode(rawValue: "group-scope")
    public static let invalidNesting = IssueCode(rawValue: "invalid-nesting")
    public static let outdatedFormatVersion = IssueCode(rawValue: "outdated-format-version")
    public static let forwardReference = IssueCode(rawValue: "forward-reference")
    public static let unknownRecallField = IssueCode(rawValue: "unknown-recall-field")
    public static let recallForwardReference = IssueCode(rawValue: "recall-forward-reference")
    public static let recallSyntax = IssueCode(rawValue: "recall-syntax")
    public static let recallSensitiveField = IssueCode(rawValue: "recall-sensitive-field")
    public static let recallQuerySource = IssueCode(rawValue: "recall-query-source")
    public static let recallUntrustedSource = IssueCode(rawValue: "recall-untrusted-source")
    public static let conditionOperatorCount = IssueCode(rawValue: "condition-operator-count")
    public static let unknownOperator = IssueCode(rawValue: "unknown-operator")
    public static let conditionValueMismatch = IssueCode(rawValue: "condition-value-mismatch")
    public static let containsNotList = IssueCode(rawValue: "contains-not-list")
    public static let containsNotInOptions = IssueCode(rawValue: "contains-not-in-options")
    public static let conditionCycle = IssueCode(rawValue: "condition-cycle")
    public static let conditionAlwaysTrue = IssueCode(rawValue: "condition-always-true")
    public static let invalidPattern = IssueCode(rawValue: "invalid-pattern")
    public static let slowPattern = IssueCode(rawValue: "slow-pattern")
    public static let invalidRange = IssueCode(rawValue: "invalid-range")
    public static let invalidScale = IssueCode(rawValue: "invalid-scale")
    public static let ruleNotApplicable = IssueCode(rawValue: "rule-not-applicable")
    public static let disabledNotApplicable = IssueCode(rawValue: "disabled-not-applicable")
    public static let missingOptions = IssueCode(rawValue: "missing-options")
    public static let defaultNotInOptions = IssueCode(rawValue: "default-not-in-options")
    public static let unknownFieldType = IssueCode(rawValue: "unknown-field-type")
    public static let customTypeName = IssueCode(rawValue: "custom-type-name")
    public static let definitionReset = IssueCode(rawValue: "definition-reset")
    public static let missingComponent = IssueCode(rawValue: "missing-component")
    public static let unknownValidator = IssueCode(rawValue: "unknown-validator")
    public static let skipUnreachable = IssueCode(rawValue: "skip-unreachable")
    public static let routeFallthrough = IssueCode(rawValue: "route-fallthrough")
    public static let unsupportedFormatVersion = IssueCode(rawValue: "unsupported-format-version")
    public static let i18nUnboundSlot = IssueCode(rawValue: "i18n-unbound-slot")
    public static let unknownI18nSlot = IssueCode(rawValue: "unknown-i18n-slot")
    public static let unknownMessageKey = IssueCode(rawValue: "unknown-message-key")
    public static let unknownLabelKey = IssueCode(rawValue: "unknown-label-key")
    public static let i18nUnsafeIdentifier = IssueCode(rawValue: "i18n-unsafe-identifier")
    public static let unknownSource = IssueCode(rawValue: "unknown-source")
    public static let sourceNotApplicable = IssueCode(rawValue: "source-not-applicable")
    public static let columnsNotApplicable = IssueCode(rawValue: "columns-not-applicable")
    public static let unknownAutocompleteToken = IssueCode(rawValue: "unknown-autocomplete-token")
    public static let autocompleteNotApplicable = IssueCode(rawValue: "autocomplete-not-applicable")
    public static let unsafeImageUrl = IssueCode(rawValue: "unsafe-image-url")
    public static let exclusiveNotApplicable = IssueCode(rawValue: "exclusive-not-applicable")
    public static let exclusiveOptionPosition = IssueCode(rawValue: "exclusive-option-position")
    public static let exclusiveDefaultValue = IssueCode(rawValue: "exclusive-default-value")
    public static let exclusiveWithMinLength = IssueCode(rawValue: "exclusive-with-min-length")
}

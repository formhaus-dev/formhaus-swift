public struct SubmissionOptions: Sendable {
    public var skippedSteps: JSONValue?
    public var validators: Validators
    public var messages: MessageSource?
    public var hiddenValues: HiddenValues

    public init(
        skippedSteps: [String]? = nil, validators: Validators = [:], messages: MessageSource? = nil, hiddenValues: HiddenValues = .clear
    ) {
        self.init(
            skippedSteps: skippedSteps.map { .array($0.map(JSONValue.string)) }, validators: validators, messages: messages,
            hiddenValues: hiddenValues)
    }

    public init(
        skippedSteps: JSONValue?, validators: Validators = [:], messages: MessageSource? = nil, hiddenValues: HiddenValues = .clear
    ) {
        self.skippedSteps = skippedSteps
        self.validators = validators
        self.messages = messages
        self.hiddenValues = hiddenValues
    }
}

public struct SubmissionResult: Sendable, Hashable {
    public let values: JSONObject
    public let errors: FieldErrors
}

private let bodyMessage = "Pass the values object as the second argument, not the request body with \"values\" and \"skippedSteps\"."

private func setError(_ visibility: VisibilityState, _ errors: inout FieldErrors, _ key: String, _ error: String) {
    errors[key] = error
    guard visibility.groups.contains(where: { sameText($0.key, key) }) else { return }
    for path in errors.keys where !sameText(path, key) && sameText(visibility.owner(path), key) { errors.removeValue(forKey: path) }
}

private func ignoredValidators(_ fields: [FormField], _ given: Validators) -> Validators {
    var validators = Validators()
    for field in fields.flatMap({ [$0] + $0.items }) {
        if let name = field.validation?.validator, !name.isEmpty { validators[name] = { _, _ in nil } }
    }
    return validators.merging(given)
}

private struct Prepared {
    let engine: EngineCore
    let skipped: [String]
    let check: () -> SubmissionResult
}

private func applySkips(_ engine: EngineCore, _ skippedSteps: JSONValue?) {
    guard let list = skippedSteps?.arrayValue else { return }
    let requested = KeySet(list.compactMap(\.stringValue))
    var index = 0
    while index < engine.visibleSteps.count {
        let step = engine.visibleSteps[index]
        if step.canSkip && requested.contains(step.id) { engine.skipStep(at: index) }
        index += 1
    }
}

private func prepare(_ definition: FormDefinition, _ fields: [FormField], _ values: JSONObject, _ options: SubmissionOptions) -> Prepared {
    let messages = messageResolver(options.messages, .catalog(definition.messages ?? .null))
    let resolve = namedResolver(messages)
    var resolved = activeValues(VisibilityState(definition), fields, values, resolve)
    let items = blankItems(&resolved, fields, resolve)
    let validators = ignoredValidators(fields, options.validators)
    let engine = EngineCore(definition: definition, values: resolved.values, validators: validators, messages: .function(messages))
    engine.loadSubmitted(resolved.values)
    applySkips(engine, options.skippedSteps)
    let skipped = engine.skipped.flatMap(\.keys)
    let invalid = resolved.invalid
    let check = { () -> SubmissionResult in
        var errors = engine.validate()
        var submitted = engine.getSubmitValues()
        let visibility = engine.visibility
        for (key, value) in invalid {
            guard let field = visibility.activeField(key, engine.values.json), !skipped.containsText(key) else { continue }
            setError(visibility, &errors, key, typeError(field, value, resolve) ?? resolve("value", [:], field))
            submitted.removeValue(forKey: key)
        }
        for (key, error) in items where submitted.has(visibility.owner(key)) && visibility.activeItem(key, engine.values.json) != nil {
            errors[key] = error
        }
        if options.hiddenValues == .keep { keepHidden(fields, resolved, &submitted, skipped, validators) }
        return SubmissionResult(values: submitted, errors: errors)
    }
    return Prepared(engine: engine, skipped: skipped, check: check)
}

private func withSkipped(_ source: JSONObject, _ prepared: Prepared) -> JSONObject {
    var values = source
    for key in prepared.skipped {
        values.removeValue(forKey: key)
        if let value = prepared.engine.values[key] { values[key] = value }
    }
    return values
}

public func validateSubmission(_ definition: JSONValue, _ values: JSONValue, options: SubmissionOptions = SubmissionOptions())
    throws(FormDefinitionError) -> SubmissionResult
{
    try validateSubmission(try FormDefinition(json: definition), values, options: options)
}

public func validateSubmission(_ definition: FormDefinition, _ values: JSONValue, options: SubmissionOptions = SubmissionOptions())
    throws(FormDefinitionError) -> SubmissionResult
{
    let quadratic = try refuseSlowPatterns(definition)
    return CallBudget.run { QuadraticPatterns.$current.withValue(quadratic) { submissionResult(definition, values, options) } }
}

private func submissionResult(_ definition: FormDefinition, _ values: JSONValue, _ options: SubmissionOptions) -> SubmissionResult {
    let fields = definition.allFields
    let source = values.objectValue ?? JSONObject()
    var prepared = prepare(definition, fields, source, options)
    var round = 0
    while round < (definition.steps?.count ?? 0) && !prepared.skipped.isEmpty {
        let next = prepare(definition, fields, withSkipped(source, prepared), options)
        let settled = sameText(next.skipped.joined(separator: ","), prepared.skipped.joined(separator: ","))
        prepared = next
        if settled { break }
        round += 1
    }
    let result = prepared.check()
    var errors = result.errors
    let isBody = values.objectValue?.has("values") == true && !fields.contains { $0.key == "values" || $0.key == "skippedSteps" }
    if isBody { errors["values"] = bodyMessage }
    return SubmissionResult(values: result.values, errors: errors)
}

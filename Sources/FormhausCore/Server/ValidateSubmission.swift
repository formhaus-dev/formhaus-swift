public struct SubmissionOptions {
    public var skippedSteps: JSONValue?
    public var validators: [String: ValidatorFn]
    public var messages: MessageSource?

    public init(skippedSteps: [String]? = nil, validators: [String: ValidatorFn] = [:], messages: MessageSource? = nil) {
        self.skippedSteps = skippedSteps.map { .array($0.map(JSONValue.string)) }
        self.validators = validators
        self.messages = messages
    }

    public init(skippedSteps: JSONValue?, validators: [String: ValidatorFn] = [:], messages: MessageSource? = nil) {
        self.skippedSteps = skippedSteps
        self.validators = validators
        self.messages = messages
    }
}

public struct SubmissionResult: Sendable, Hashable {
    public let values: JSONObject
    public let errors: [String: String]
}

private let bodyMessage = "Pass the values object as the second argument, not the request body with \"values\" and \"skippedSteps\"."

private func setError(_ visibility: VisibilityState, _ errors: inout [String: String], _ key: String, _ error: String) {
    errors[key] = error
    guard visibility.groups.contains(where: { $0.key == key }) else { return }
    for path in errors.keys where path != key && visibility.owner(path) == key { errors.removeValue(forKey: path) }
}

private func ignoredValidators(_ fields: [FormField], _ given: [String: ValidatorFn]) -> [String: ValidatorFn] {
    var validators: [String: ValidatorFn] = [:]
    for field in fields.flatMap({ [$0] + $0.items }) {
        if let name = field.validation?.validator, !name.isEmpty { validators[name] = { _, _ in nil } }
    }
    return validators.merging(given) { $1 }
}

private struct Prepared {
    let engine: FormEngine
    let skipped: [String]
    let check: () -> SubmissionResult
}

private func itemErrors(_ engine: FormEngine, _ invalid: Set<String>, _ resolve: @escaping ResolveMessage) -> [(key: String, error: String)] {
    var errors: [(key: String, error: String)] = []
    for group in engine.visibility.groups where !invalid.contains(group.key) {
        guard let active = engine.visibility.activeField(group.key, engine.values), active.isGroup else { continue }
        let items = itemsOf(engine.values[group.key])
        let next = items.enumerated().map { index, item -> JSONValue in
            guard var entry = item.objectValue else { return item }
            for field in engine.visibility.itemFields(active, item, engine.values) {
                guard let error = typeError(field, entry[field.key], resolve) else { continue }
                errors.append((itemPath(group.key, index, field.key), error))
                entry.removeValue(forKey: field.key)
            }
            return .object(entry)
        }
        if next != items { engine.writeValue(group.key, .array(next)) }
    }
    return errors
}

private func dropUnchecked(_ engine: FormEngine, _ submitted: inout JSONObject, _ errors: inout [String: String], _ resolve: @escaping ResolveMessage) {
    let visibility = engine.visibility
    for key in submitted.keys {
        guard let field = visibility.activeField(key, engine.values), errors[key] == nil else { continue }
        if let error = typeError(field, submitted[key], resolve) {
            setError(visibility, &errors, key, error)
            submitted.removeValue(forKey: key)
            continue
        }
        guard field.isGroup else { continue }
        let items = itemsOf(submitted[key])
        let next = items.enumerated().map { index, item -> JSONValue in
            guard var entry = item.objectValue else { return item }
            for itemField in visibility.itemFields(field, item, engine.values) {
                guard let error = typeError(itemField, entry[itemField.key], resolve) else { continue }
                errors[itemPath(key, index, itemField.key)] = error
                entry.removeValue(forKey: itemField.key)
            }
            return .object(entry)
        }
        if next != items { submitted[key] = .array(next) }
    }
}

private func applySkips(_ engine: FormEngine, _ skippedSteps: JSONValue?) {
    guard let requested = skippedSteps?.arrayValue else { return }
    var index = 0
    while index < engine.visibleSteps.count {
        let step = engine.visibleSteps[index]
        if step.canSkip && requested.contains(where: { strictEquals($0, .string(step.id)) }) { engine.skipStep(at: index) }
        index += 1
    }
}

private func prepare(_ definition: FormDefinition, _ fields: [FormField], _ values: JSONObject, _ options: SubmissionOptions) -> Prepared {
    let messages = messageResolver(options.messages, .catalog(definition.messages ?? .null))
    let resolve = namedResolver(messages)
    let visibility = VisibilityState(definition)
    let groups = rejectGroups(visibility, fields, values, resolve)
    let resolved = groups.resolved
    let invalid = typeErrors(resolved, resolve)
    let invalidKeys = Set(invalid.map(\.key))
    let engineOptions = FormEngineOptions(validators: ignoredValidators(fields, options.validators), messages: .function(messages))
    let engine = FormEngine(definition: withoutRules(definition, invalidKeys), values: resolved.values, options: engineOptions)
    engine.loadSubmitted(resolved.values)
    let items = itemErrors(engine, invalidKeys, resolve)
    applySkips(engine, options.skippedSteps)
    let skipped = engine.skipped.flatMap(\.keys)
    let check = { () -> SubmissionResult in
        var errors = engine.validate()
        var submitted = engine.getSubmitValues()
        let visibility = engine.visibility
        for (key, error) in invalid where submitted.has(key) {
            setError(visibility, &errors, key, error)
            submitted[key] = resolved.values[key]
        }
        for (key, value) in groups.rejected {
            guard let field = visibility.activeField(key, engine.values), !skipped.contains(key) else { continue }
            setError(visibility, &errors, key, typeError(field, value, resolve) ?? resolve("value", [:], field))
            submitted.removeValue(forKey: key)
        }
        for (key, error) in items where submitted.has(visibility.owner(key)) && visibility.activeItem(key, engine.values) != nil {
            errors[key] = error
        }
        dropUnchecked(engine, &submitted, &errors, resolve)
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

public func validateSubmission(_ definition: JSONValue, _ values: JSONValue, options: SubmissionOptions = SubmissionOptions()) throws(FormDefinitionError) -> SubmissionResult {
    validateSubmission(try FormDefinition(json: definition), values, options: options)
}

public func validateSubmission(_ definition: FormDefinition, _ values: JSONValue, options: SubmissionOptions = SubmissionOptions()) -> SubmissionResult {
    let fields = definition.allFields
    let source = values.objectValue ?? JSONObject()
    var prepared = prepare(definition, fields, source, options)
    var round = 0
    while round < (definition.steps?.count ?? 0) && !prepared.skipped.isEmpty {
        let next = prepare(definition, fields, withSkipped(source, prepared), options)
        let settled = next.skipped.joined(separator: ",") == prepared.skipped.joined(separator: ",")
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

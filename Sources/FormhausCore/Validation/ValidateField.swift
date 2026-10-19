public typealias ValidatorFn = (JSONValue, JSONObject) -> String?

private func isEmptyValue(_ value: JSONValue?, _ field: FormField) -> Bool {
    isBlank(value) || (value == .bool(false) && booleanTypes.contains(field.type))
}

private func boundError(_ size: Double, _ rule: String, _ rules: FieldValidation, _ message: (String, JSONObject) -> String) -> String? {
    if let min = rules.json["min\(rule)"]?.numberValue, size < min {
        return rules.message("min\(rule)Message") ?? message("min", ["min": .number(min)])
    }
    if let max = rules.json["max\(rule)"]?.numberValue, size > max {
        return rules.message("max\(rule)Message") ?? message("max", ["max": .number(max)])
    }
    return nil
}

private func patternError(_ value: JSONValue, _ rules: FieldValidation, _ message: () -> String) -> String? {
    guard let source = rules.pattern, let pattern = JSRegex(source) else { return nil }
    let text = jsString(value)
    guard text.jsLength <= maxStringLength else { return rules.message("patternMessage") ?? message() }
    guard let matched = pattern.test(text) else { return nil }
    return matched ? nil : rules.message("patternMessage") ?? message()
}

private func sizeError(_ value: JSONValue, _ rules: FieldValidation, _ field: FormField, _ resolve: ResolveMessage) -> String? {
    switch value {
    case .number(let number):
        return boundError(number, "", rules) { resolve($0, $1, field) }
    case .string(let text):
        return boundError(Double(text.jsLength), "Length", rules) { resolve("\($0)Length", $1, field) }
    case .array(let items):
        return boundError(Double(items.count), "Length", rules) { resolve("\($0)Items", $1, field) }
    default:
        return nil
    }
}

public func validateFieldValue(
    _ field: FormField, _ input: JSONValue?, _ allValues: JSONObject, validators: [String: ValidatorFn] = [:],
    messages: MessageSource? = nil
) -> String? {
    let value = trimValue(field, input)
    let rules = field.validation ?? FieldValidation(json: JSONObject())
    let resolve = namedResolver(messageResolver(messages))
    let matchMessage = { rules.message("matchFieldMessage") ?? resolve("matchField", [:], field) }
    guard let present = value, !isEmptyValue(value, field) else {
        if let required = rules.required, required.isTruthy {
            return required.stringValue ?? resolve("required", [:], field)
        }
        if let match = rules.matchField, !isBlank(allValues[match]) { return matchMessage() }
        return nil
    }
    if let issue = clientTypeError(field, present, resolve), !issue.isEmpty { return issue }
    let issue =
        sizeError(present, rules, field, resolve)
        ?? patternError(present, rules, { resolve("pattern", [:], field) })
        ?? rules.matchField.flatMap { strictEquals(present, allValues[$0]) ? nil : matchMessage() }
        ?? rules.validator.flatMap { validators[$0]?(present, allValues) }
    return issue?.isEmpty == false ? issue : nil
}

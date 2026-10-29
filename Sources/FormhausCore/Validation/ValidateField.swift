public typealias ValidatorFn = @Sendable (JSONValue, JSONObject) -> String?
public typealias Validators = StringMap<ValidatorFn>

public struct ValidateOptions: Sendable {
    public var validators: Validators
    public var messages: MessageSource?

    public init(validators: Validators = [:], messages: MessageSource? = nil) {
        self.validators = validators
        self.messages = messages
    }
}

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
    return rejects(pattern, jsString(value)) ? rules.message("patternMessage") ?? message() : nil
}

func rejects(_ pattern: JSRegex, _ text: String) -> Bool {
    text.jsLength > maxStringLength || CallBudget.current?.admitsPatternTest() == false || pattern.test(text) != true
}

private func sizeError(_ value: JSONValue, _ rules: FieldValidation, _ field: FormField, _ resolve: ResolveMessage) -> String? {
    switch value {
    case .number(let number):
        return boundError(number, "", rules) { resolve(MessageKey(rawValue: $0), $1, field) }
    case .string(let text):
        return boundError(Double(text.jsLength), "Length", rules) { resolve(MessageKey(rawValue: "\($0)Length"), $1, field) }
    case .array(let items):
        var bounds = rules
        if items.count == 1, exclusiveValues(field).contains(where: { strictEquals($0, items[0]) }) {
            var json = rules.json
            json.removeValue(forKey: "minLength")
            bounds = FieldValidation(json: json)
        }
        return boundError(Double(items.count), "Length", bounds) { resolve(MessageKey(rawValue: "\($0)Items"), $1, field) }
    default:
        return nil
    }
}

@_spi(Renderer) public func fileItems(_ value: JSONValue?) -> [JSONValue] {
    switch value {
    case .array(let items)?: items
    case nil, .null?, .string("")?: []
    case let single?: [single]
    }
}

private func fileListRules(_ field: FormField) -> FieldValidation {
    var json = field.validation?.json ?? JSONObject()
    json["maxLength"] = .number(Double(field.fileListLimit))
    return FieldValidation(json: json)
}

public func validateFieldValue(
    _ field: FormField, _ input: JSONValue?, _ allValues: JSONObject, options: ValidateOptions = ValidateOptions()
) -> String? {
    CallBudget.run { fieldValueError(field, input, allValues, options.validators, options.messages) }
}

func fieldValueError(
    _ field: FormField, _ input: JSONValue?, _ allValues: JSONObject, _ validators: Validators, _ messages: MessageSource?,
    required: Bool = true
) -> String? {
    let value = field.isFileList ? .array(fileItems(input)) : trimValue(field, input)
    let rules = field.isFileList ? fileListRules(field) : field.validation ?? FieldValidation(json: JSONObject())
    let resolve = namedResolver(messageResolver(messages))
    let matchMessage = { rules.message("matchFieldMessage") ?? resolve("matchField", [:], field) }
    guard let present = value, !isEmptyValue(value, field) else {
        if required, let rule = rules.required, rule.isTruthy {
            return rule.stringValue ?? resolve("required", [:], field)
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

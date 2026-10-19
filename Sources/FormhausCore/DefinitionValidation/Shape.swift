import Foundation

private let versionPattern = JSRegex("^[1-9]\\d*(\\.\\d+)?$")!

func nestable(_ path: String) -> Bool {
    path.components(separatedBy: "/fields/").count <= 3
}

private enum Kind {
    case string, number, boolean, requirement, scalar, list

    func accepts(_ value: JSONValue) -> Bool {
        switch self {
        case .string: value.stringValue != nil
        case .number: value.isFiniteNumber
        case .boolean: value.boolValue != nil
        case .requirement: value.boolValue != nil || value.stringValue != nil
        case .scalar: ["string", "number", "boolean"].contains(value.typeName)
        case .list: value.arrayValue?.allSatisfy { $0.stringValue != nil || $0.numberValue != nil } == true
        }
    }

    var name: String {
        switch self {
        case .string: "a string"
        case .number: "a number"
        case .boolean: "true or false"
        case .requirement: "true, false or a message string"
        case .scalar: "a string, number or boolean"
        case .list: "an array of strings or numbers"
        }
    }
}

private typealias Check = (JSONObject, String) -> [DefinitionIssue]

private func typed(_ value: JSONObject, _ rules: KeyValuePairs<String, Kind>, _ path: String) -> [DefinitionIssue] {
    rules.flatMap { key, kind -> [DefinitionIssue] in
        guard let item = value[key], !kind.accepts(item) else { return [] }
        return [error("invalid-type", "\(path)/\(pointer(key))", "\"\(key)\" must be \(kind.name)")]
    }
}

func missing(_ path: String, _ key: String, _ hint: String? = nil, severity: DefinitionIssue.Severity = .error) -> DefinitionIssue {
    DefinitionIssue(severity, "missing-property", path, "missing required property \"\(key)\"", hint)
}

private func list(_ value: JSONValue?, _ path: String, _ name: String, _ check: Check, required: Bool = false) -> [DefinitionIssue] {
    if !required && (value == nil || value?.isNull == true) { return [] }
    guard let value else {
        let slash = path.range(of: "/", options: .backwards)!
        return [missing(String(path[..<slash.lowerBound]), String(path[slash.upperBound...]))]
    }
    guard let items = value.arrayValue else {
        return [error("invalid-type", path, "must be an array", required ? "Use [] when there is nothing to list" : nil)]
    }
    return items.enumerated().flatMap { index, item -> [DefinitionIssue] in
        guard let object = item.objectValue else { return [error("invalid-type", "\(path)/\(index)", "must be \(name)")] }
        return check(object, "\(path)/\(index)")
    }
}

private func text(_ value: JSONObject, _ key: String, _ path: String) -> [DefinitionIssue] {
    guard let item = value[key] else { return [missing(path, key)] }
    return item.stringValue != nil ? [] : [error("invalid-type", "\(path)/\(pointer(key))", "\"\(key)\" must be a string")]
}

private func condition(_ value: JSONObject, _ path: String) -> [DefinitionIssue] {
    typed(
        value,
        [
            "field": .string, "eq": .scalar, "neq": .scalar, "in": .list, "notIn": .list, "notEmpty": .boolean,
            "gt": .number, "gte": .number, "lt": .number, "lte": .number,
        ],
        path
    )
}

private func conditionLists(_ value: JSONObject, _ path: String) -> [DefinitionIssue] {
    list(value["show"], "\(path)/show", "a condition object", condition)
        + list(value["showAny"], "\(path)/showAny", "a condition object", condition)
}

private func action(_ value: JSONValue?, _ path: String) -> [DefinitionIssue] {
    guard let object = value?.objectValue else { return [] }
    return typed(object, ["label": .string], path) + list(object["disabled"], "\(path)/disabled", "a condition object", condition)
}

private func option(_ value: JSONObject, _ path: String) -> [DefinitionIssue] {
    text(value, "value", path) + typed(value, ["label": .string], path)
}

private let rules: KeyValuePairs<String, Kind> = [
    "required": .requirement, "minLength": .number, "maxLength": .number, "min": .number, "max": .number,
    "pattern": .string, "matchField": .string, "validator": .string, "minLengthMessage": .string,
    "maxLengthMessage": .string, "minMessage": .string, "maxMessage": .string, "patternMessage": .string,
    "matchFieldMessage": .string,
]

private func validation(_ value: JSONValue?, _ path: String) -> [DefinitionIssue] {
    guard let value else { return [] }
    guard let object = value.objectValue else { return [error("invalid-type", path, "must be an object of validation rules")] }
    return typed(object, rules, path)
}

private func props(_ value: JSONValue?, _ path: String) -> [DefinitionIssue] {
    value == nil || value?.objectValue != nil ? [] : [error("invalid-type", path, "must be an object")]
}

private func dependencies(_ value: JSONValue?, _ path: String) -> [DefinitionIssue] {
    let valid = value == nil || value?.arrayValue?.allSatisfy { $0.stringValue != nil } == true
    return valid ? [] : [error("invalid-type", path, "must be an array of field keys")]
}

private func field(_ value: JSONObject, _ path: String) -> [DefinitionIssue] {
    let type = value["type"]?.stringValue
    let container = (type == "section" || type == "group") && nestable(path)
    let labels: KeyValuePairs<String, Kind> = [
        "label": .string, "placeholder": .string, "helperText": .string, "title": .string, "description": .string,
        "itemLabel": .string, "addLabel": .string, "removeLabel": .string, "defaultItems": .number,
    ]
    return text(value, "key", path) + text(value, "type", path) + typed(value, labels, path)
        + (container ? list(value["fields"], "\(path)/fields", "a field object", field, required: true) : [])
        + conditionLists(value, path)
        + list(value["options"], "\(path)/options", "an option object", option)
        + validation(value["validation"], "\(path)/validation")
        + dependencies(value["optionsDependsOn"], "\(path)/optionsDependsOn")
        + props(value["props"], "\(path)/props")
}

private func route(_ value: JSONObject, _ path: String) -> [DefinitionIssue] {
    let target: [DefinitionIssue]
    switch value["to"] {
    case nil: target = [missing(path, "to")]
    case .null?, .string?: target = []
    default: target = [error("invalid-type", "\(path)/to", "\"to\" must be a step id or null")]
    }
    return target + conditionLists(value, path)
}

private func step(_ value: JSONObject, _ path: String) -> [DefinitionIssue] {
    text(value, "id", path) + typed(value, ["title": .string, "description": .string], path)
        + list(value["fields"], "\(path)/fields", "a field object", field, required: true)
        + conditionLists(value, path)
        + list(value["routes"], "\(path)/routes", "a route object", route)
        + ["next", "back", "skip"].flatMap { action(value[$0], "\(path)/\($0)") }
}

func formatIssues(_ input: JSONObject) -> [DefinitionIssue] {
    guard let version = input["formatVersion"] else { return [] }
    let text = version.stringValue
    let valid = text.map { versionPattern.test($0) == true } ?? false
    if valid, Double(text!.prefix { $0 != "." })! <= Double(FormDefinition.supportedFormatVersion.prefix { $0 != "." })! { return [] }
    return [
        valid
            ? error("unsupported-format-version", "/formatVersion", "format \(text!) is not supported", "Upgrade @formhaus/core")
            : error("invalid-type", "/formatVersion", "must be a version string", "Use \"\(FormDefinition.supportedFormatVersion)\""),
    ]
}

func shapeIssues(_ input: JSONValue) -> [DefinitionIssue] {
    guard let object = input.objectValue else { return [error("invalid-type", "", "the form definition must be an object")] }
    let format = formatIssues(object)
    if !format.isEmpty { return format }
    return list(object["fields"], "/fields", "a field object", field)
        + list(object["steps"], "/steps", "a step object", step)
        + action(object["submit"], "/submit")
        + action(object["cancel"], "/cancel")
}

private let submitHint = "Add \"submit\": { \"label\": \"Submit\" }"

func metaIssues(_ input: JSONObject) -> [DefinitionIssue] {
    let submit: [DefinitionIssue]
    switch input["submit"] {
    case nil: submit = [missing("", "submit", submitHint)]
    case .object?: submit = []
    default: submit = [error("invalid-type", "/submit", "must be an action object", submitHint)]
    }
    return text(input, "id", "") + submit
}

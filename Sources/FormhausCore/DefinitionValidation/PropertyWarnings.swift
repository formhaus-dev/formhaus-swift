enum Properties {
    static let form: [String] = [
        "$schema", "formatVersion", "id", "lang", "title", "description", "messages", "labels", "i18n", "submit", "cancel", "fields",
        "steps",
    ]
    static let step: [String] = ["id", "title", "description", "fields", "show", "showAny", "routes", "next", "back", "skip", "i18n"]
    static let field: [String] = [
        "key", "type", "label", "placeholder", "helperText", "autoAdvance", "defaultValue", "source", "show", "showAny", "validation",
        "options", "randomize", "layout", "columns", "optionsFrom", "optionsDependsOn", "accept", "multiple", "rows", "mask", "inputMode",
        "autocomplete", "readOnly", "props", "i18n",
    ]
    static let section: [String] = ["key", "type", "title", "description", "layout", "show", "showAny", "fields", "i18n"]
    static let group: [String] = [
        "key", "type", "label", "helperText", "itemLabel", "addLabel", "removeLabel", "defaultItems", "reorderable", "show", "showAny",
        "validation", "fields", "i18n",
    ]
    static let option: [String] = ["value", "label", "image", "exclusive", "pinned", "description", "disabled", "i18n"]
    static let since: [(minor: Double, key: String)] = [
        (7, "multiple"), (8, "readOnly"), (8, "reorderable"), (8, "description"), (8, "disabled"),
    ]

    static func known(_ list: [String], _ definition: FormDefinition) -> [String] {
        let format = definition.json["formatVersion"]
        let later = since.filter { !formatAtLeast(format, $0.minor) }.map(\.key)
        return list.filter { !later.contains($0) }
    }

    static func newer(_ list: [String], _ definition: FormDefinition) -> (String) -> String? {
        { key in
            guard list.contains(key), let entry = since.first(where: { $0.key == key }),
                !formatAtLeast(definition.json["formatVersion"], entry.minor)
            else { return nil }
            return "Set \"formatVersion\": \"1.\(Int(entry.minor))\" to use it"
        }
    }
    static let action: [String] = ["label", "variant", "disabled", "i18n"]
    static let route: [String] = ["to", "show", "showAny"]
    static let validation: [String] = [
        "required", "minLength", "minLengthMessage", "maxLength", "maxLengthMessage", "min", "minMessage", "max", "maxMessage", "pattern",
        "patternMessage", "matchField", "matchFieldMessage", "validator", "i18n",
    ]
}

private let safeImage = JSRegex(unchecked: "^(?i:https:|data:image\\/)")
private let labelHint = "Add a label so screen readers can name the input"

private func unknown(_ value: JSONObject, _ path: String, _ known: [String], hint: (String) -> String? = { _ in nil }) -> [DefinitionIssue]
{
    let absent = known.filter { !value.has($0) }
    return value.keys.filter { !known.containsText($0) }.map { key in
        let fix = closest(key, absent).map { "Did you mean \"\($0)\"?" } ?? hint(key)
        return warning("unknown-property", "\(path)/\(pointer(key))", "unknown property \"\(key)\"", fix)
    }
}

private func required(_ value: JSONObject, _ path: String, _ key: String, _ hint: String? = nil) -> [DefinitionIssue] {
    value.has(key) ? [] : [missing(path, key, hint, severity: .warning)]
}

private func labeled(_ value: JSONObject, _ path: String, _ hint: String? = nil) -> [DefinitionIssue] {
    value.has("label") ? [] : [warning("missing-label", "\(path)/label", "missing required property \"label\"", hint)]
}

private func action(_ value: JSONValue?, _ path: String, disables: Bool = true) -> [DefinitionIssue] {
    guard let object = value?.objectValue else { return [] }
    let ignored = !disables && object.has("disabled")
    return labeled(object, path) + unknown(object, path, Properties.action)
        + (ignored
            ? [
                warning(
                    "disabled-not-applicable", "\(path)/disabled", "the built-in renderers ignore \"disabled\" on this button",
                    "Remove \"disabled\"")
            ] : [])
}

private func misplaced(_ key: String) -> String? {
    !sameText(key, "i18n") && Properties.validation.containsText(key)
        ? "Move \"\(key)\" into \"validation\": { \"\(key)\": ... }" : nil
}

private func optionWarnings(_ field: FormField, _ option: FieldOption, _ at: String, _ definition: FormDefinition) -> [DefinitionIssue] {
    let known = Properties.known(Properties.option, definition)
    var issues = labeled(option.json, at) + unknown(option.json, at, known, hint: Properties.newer(Properties.option, definition))
    if definition.optionRules, option.json.has("disabled"), !randomizedTypes.contains(field.type) {
        issues.append(
            warning(
                "disabled-not-applicable", "\(at)/disabled",
                "\"disabled\" on an option of \"\(field.key)\" applies to radio, multiselect and select fields", "Remove \"disabled\""))
    }
    if let image = option.image, safeImage.test(image) != true {
        issues.append(
            warning(
                "unsafe-image-url", "\(at)/image",
                "the image of option \"\(option.value ?? "")\" in \"\(field.key)\" is not an https: or data:image/ URL",
                "Serve the image over https"))
    }
    if option.pinned && !field.randomize {
        issues.append(
            warning("randomize-not-applicable", "\(at)/pinned", "\"\(field.key)\" does not set \"randomize\"", "Remove \"pinned\""))
    }
    return issues
}

private func randomizeWarnings(_ entry: FieldEntry) -> [DefinitionIssue] {
    let field = entry.field
    guard field.randomize, !randomizedTypes.contains(field.type) || entry.parent?.json["layout"]?.stringValue == "matrix" else { return [] }
    return [
        warning(
            "randomize-not-applicable", "\(entry.path)/randomize",
            "\"randomize\" of \"\(field.key)\" applies to radio, multiselect and select fields outside a matrix",
            "Remove \"randomize\"")
    ]
}

private func optionValues(_ json: JSONObject) -> [JSONValue]? {
    if json["optionsFrom"]?.isTruthy == true { return nil }
    return json["options"]?.arrayValue?.map { $0.objectValue?["value"] ?? .null }
}

private func matrixWarnings(_ entry: FieldEntry) -> [DefinitionIssue] {
    let field = entry.field
    guard let matrix = entry.parent?.section, matrix.json["layout"]?.stringValue == "matrix",
        let columns = matrix.fields.first.flatMap({ optionValues($0.json) }),
        field.type == "radio" || field.type == "multiselect",
        (optionValues(field.json) ?? columns) != columns
    else { return [] }
    return [
        warning(
            "matrix-options-mismatch", "\(entry.path)/options",
            "the option values of \"\(field.key)\" differ from the columns of the matrix \"\(matrix.key)\"",
            "Use the options of the first field in every row")
    ]
}

private func multipleWarnings(_ entry: FieldEntry) -> [DefinitionIssue] {
    guard entry.field.json.has("multiple"), entry.field.type != "file" else { return [] }
    return [
        warning(
            "multiple-not-applicable", "\(entry.path)/multiple", "\"multiple\" of \"\(entry.field.key)\" applies to file fields",
            "Remove \"multiple\"")
    ]
}

private func disabledDefault(_ entry: FieldEntry, _ definition: FormDefinition) -> [DefinitionIssue] {
    let field = entry.field
    guard definition.optionRules else { return [] }
    let defaults: [JSONValue?] =
        if case .array(let items)? = field.defaultValue { items } else { [field.defaultValue] }
    let option = (field.options ?? []).first { option in
        let rule = option.json["disabled"]
        let disabled = rule == .bool(true) || rule?.arrayValue?.isEmpty == false
        return disabled && defaults.contains { sameValueZero($0, option.json["value"]) }
    }
    guard let option else { return [] }
    return [
        warning(
            "default-disabled-option", "\(entry.path)/defaultValue",
            "the defaultValue of \"\(field.key)\" is the disabled option \"\(option.value ?? "")\"", "Pick an enabled option as the default"
        )
    ]
}

private func fieldWarnings(_ entry: FieldEntry, _ definition: FormDefinition) -> [DefinitionIssue] {
    let listsFiles = definition.listsFiles
    let field = entry.field
    let path = entry.path
    let visible = field.type != "hidden"
    let empty = visible && field.label.map(\.isBlankText) == true
    var issues = visible ? labeled(field.json, path, labelHint) : []
    if empty { issues.append(warning("missing-label", "\(path)/label", "the label of \"\(field.key)\" is empty", labelHint)) }
    let list = field.isGroup ? Properties.group : Properties.field
    let newer = Properties.newer(list, definition)
    issues += unknown(field.json, path, Properties.known(list, definition)) { misplaced($0) ?? newer($0) }
    for (index, option) in (field.options ?? []).enumerated() {
        issues += optionWarnings(field, option, "\(path)/options/\(index)", definition)
    }
    issues +=
        randomizeWarnings(entry) + matrixWarnings(entry) + disabledDefault(entry, definition)
        + (listsFiles ? multipleWarnings(entry) : [])
    if let validation = field.validation { issues += unknown(validation.json, "\(path)/validation", Properties.validation) }
    if field.json["columns"] != nil, !field.hasPictures || entry.parent?.json["layout"]?.stringValue == "matrix" {
        issues.append(
            warning(
                "columns-not-applicable", "\(path)/columns",
                "\"columns\" of \"\(field.key)\" applies to radio and multiselect options with images outside a matrix",
                "Remove \"columns\""))
    }
    return issues
}

func propertyWarnings(_ context: CheckContext) -> [DefinitionIssue] {
    let definition = context.definition
    let root = definition.json
    var issues = required(root, "", "title", "Add a title for host UI and editors")
    if let title = root["title"], title.stringValue == nil {
        issues.append(warning("invalid-type", "/title", "\"title\" must be a string"))
    }
    issues += unknown(root, "", Properties.form) + action(root["submit"], "/submit") + action(root["cancel"], "/cancel", disables: false)
    for (index, step) in (definition.steps ?? []).enumerated() {
        let path = "/steps/\(index)"
        issues += required(step.json, path, "title") + unknown(step.json, path, Properties.step)
        for (position, route) in (step.routes ?? []).enumerated() {
            issues += unknown(route.json, "\(path)/routes/\(position)", Properties.route)
        }
        for name in ["next", "back", "skip"] {
            issues += action(step.json[name], "\(path)/\(name)", disables: name == "next")
        }
    }
    for entry in context.nodes where entry.node.section != nil {
        issues += required(entry.node.json, entry.path, "title") + unknown(entry.node.json, entry.path, Properties.section)
    }
    return issues + context.entries.flatMap { fieldWarnings($0, definition) }
}

enum Properties {
    static let form: [String] = [
        "$schema", "formatVersion", "id", "lang", "title", "description", "messages", "labels", "i18n", "submit", "cancel", "fields",
        "steps",
    ]
    static let step: [String] = ["id", "title", "description", "fields", "show", "showAny", "routes", "next", "back", "skip", "i18n"]
    static let field: [String] = [
        "key", "type", "label", "placeholder", "helperText", "autoAdvance", "defaultValue", "source", "show", "showAny", "validation",
        "options", "randomize", "layout", "columns", "optionsFrom", "optionsDependsOn", "accept", "rows", "mask", "inputMode",
        "autocomplete", "props", "i18n",
    ]
    static let section: [String] = ["key", "type", "title", "description", "layout", "show", "showAny", "fields", "i18n"]
    static let group: [String] = [
        "key", "type", "label", "helperText", "itemLabel", "addLabel", "removeLabel", "defaultItems", "show", "showAny", "validation",
        "fields", "i18n",
    ]
    static let option: [String] = ["value", "label", "image", "exclusive", "pinned", "i18n"]
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

private func optionWarnings(_ field: FormField, _ option: FieldOption, _ at: String) -> [DefinitionIssue] {
    var issues = labeled(option.json, at) + unknown(option.json, at, Properties.option)
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

private func fieldWarnings(_ entry: FieldEntry) -> [DefinitionIssue] {
    let field = entry.field
    let path = entry.path
    let visible = field.type != "hidden"
    let empty = visible && field.label.map(\.isBlankText) == true
    var issues = visible ? labeled(field.json, path, labelHint) : []
    if empty { issues.append(warning("missing-label", "\(path)/label", "the label of \"\(field.key)\" is empty", labelHint)) }
    issues += unknown(field.json, path, field.isGroup ? Properties.group : Properties.field, hint: misplaced)
    for (index, option) in (field.options ?? []).enumerated() {
        issues += optionWarnings(field, option, "\(path)/options/\(index)")
    }
    issues += randomizeWarnings(entry)
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
    return issues + context.entries.flatMap(fieldWarnings)
}

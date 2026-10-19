enum Properties {
    static let form = "$schema formatVersion id lang title description messages labels i18n submit cancel fields steps"
    static let step = "id title description fields show showAny routes next back skip i18n"
    static let field =
        "key type label placeholder helperText autoAdvance defaultValue source show showAny validation options layout optionsFrom optionsDependsOn accept rows mask inputMode props i18n"
    static let section = "key type title description show showAny fields i18n"
    static let group = "key type label helperText itemLabel addLabel removeLabel defaultItems show showAny validation fields i18n"
    static let option = "value label i18n"
    static let action = "label variant disabled i18n"
    static let route = "to show showAny"
    static let validation =
        "required minLength minLengthMessage maxLength maxLengthMessage min minMessage max maxMessage pattern patternMessage matchField matchFieldMessage validator i18n"
}

private let labelHint = "Add a label so screen readers can name the input"

private func unknown(_ value: JSONObject, _ path: String, _ list: String, hint: (String) -> String? = { _ in nil }) -> [DefinitionIssue] {
    let known = list.split(separator: " ").map(String.init)
    let absent = known.filter { !value.has($0) }
    return value.keys.filter { !known.contains($0) }.map { key in
        let fix = closest(key, absent).map { "Did you mean \"\($0)\"?" } ?? hint(key)
        return warning("unknown-property", "\(path)/\(pointer(key))", "unknown property \"\(key)\"", fix)
    }
}

private func required(_ value: JSONObject, _ path: String, _ key: String, _ hint: String? = nil) -> [DefinitionIssue] {
    value.has(key) ? [] : [missing(path, key, hint, severity: .warning)]
}

private func action(_ value: JSONValue?, _ path: String, disables: Bool = true) -> [DefinitionIssue] {
    guard let object = value?.objectValue else { return [] }
    let ignored = !disables && object.has("disabled")
    return required(object, path, "label") + unknown(object, path, Properties.action)
        + (ignored ? [warning("disabled-not-applicable", "\(path)/disabled", "the built-in renderers ignore \"disabled\" on this button", "Remove \"disabled\"")] : [])
}

private func misplaced(_ key: String) -> String? {
    key != "i18n" && Properties.validation.split(separator: " ").contains(Substring(key))
        ? "Move \"\(key)\" into \"validation\": { \"\(key)\": ... }" : nil
}

private func fieldWarnings(_ entry: FieldEntry) -> [DefinitionIssue] {
    let field = entry.field
    let path = entry.path
    let visible = field.type != "hidden"
    let empty = visible && field.label.map(\.isBlankText) == true
    var issues = visible ? required(field.json, path, "label", labelHint) : []
    if empty { issues.append(warning("empty-label", "\(path)/label", "the label of \"\(field.key)\" is empty", labelHint)) }
    issues += unknown(field.json, path, field.isGroup ? Properties.group : Properties.field, hint: misplaced)
    for (index, option) in (field.options ?? []).enumerated() {
        issues += required(option.json, "\(path)/options/\(index)", "label") + unknown(option.json, "\(path)/options/\(index)", Properties.option)
    }
    if let validation = field.validation { issues += unknown(validation.json, "\(path)/validation", Properties.validation) }
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

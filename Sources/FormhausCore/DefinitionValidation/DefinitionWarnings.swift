private let listOperators = ["in", "notIn"]
private let comparisons = ["gt", "gte", "lt", "lte"]

private func expectedType(_ field: FormField) -> String? {
    if numberTypes.contains(field.type) { return "number" }
    if booleanTypes.contains(field.type) { return "boolean" }
    return builtInTypes.contains(field.type) && !listTypes.contains(field.type) && field.type != "file" ? "string" : nil
}

private func mismatch(_ name: String, _ path: String, _ problem: String, _ hint: String) -> [DefinitionIssue] {
    [warning(containsOperators.contains(name) ? "contains-not-list" : "condition-value-mismatch", path, problem, hint)]
}

private func valueIssue(_ target: FormField, _ name: String, _ operand: JSONValue?, _ path: String) -> [DefinitionIssue] {
    let contains = containsOperators.contains(name)
    let list = listTypes.contains(target.type)
    if name == "notEmpty" {
        return operand?.isTruthy == true
            ? []
            : [
                warning(
                    "condition-always-true", path, "\"notEmpty\": false matches every value",
                    "Use \"notEmpty\": true, or remove the condition")
            ]
    }
    if comparisons.contains(name) || (contains && !list) {
        let checked = contains ? builtInTypes.contains(target.type) || target.isGroup : list || booleanTypes.contains(target.type)
        guard checked else { return [] }
        return mismatch(
            name, path,
            "\"\(target.key)\" is a \(target.type) field, so \"\(name)\" \(name == "notContains" ? "always" : "never") matches it",
            contains ? "Use eq or in, or test a multiselect field" : "Compare a number, text, radio or select field")
    }
    if list && !contains {
        let result = name == "neq" || name == "notIn" ? "always" : "never"
        return mismatch(
            name, path, "\"\(target.key)\" holds a list of values, so \"\(name)\" \(result) matches it",
            "Use contains, notContains or notEmpty")
    }
    return operandIssue(target, name, operand, path)
}

private func operandIssue(_ target: FormField, _ name: String, _ operand: JSONValue?, _ path: String) -> [DefinitionIssue] {
    let list = listTypes.contains(target.type)
    let operands: [JSONValue?]
    if listOperators.contains(name), let list = operand?.arrayValue { operands = list } else { operands = [operand] }
    let expected = expectedType(target)
    if let expected, let wrong = operands.first(where: { ($0?.typeName ?? "undefined") != expected }) {
        return mismatch(
            name, path, "\(jsonStringify(wrong)) is a \(wrong?.typeName ?? "undefined"), but \"\(target.key)\" holds a \(expected)",
            "Use a \(expected) value")
    }
    guard expected == "string" || list, !target.hasOptionsFrom, let options = target.options, !options.isEmpty else { return [] }
    let values = options.compactMap(\.value)
    guard let missing = operands.first(where: { item in !values.contains { strictEquals(.string($0), item) } }) else { return [] }
    return [
        warning(
            containsOperators.contains(name) ? "contains-not-in-options" : "condition-value-mismatch", path,
            "\(jsonStringify(missing)) is not an option of \"\(target.key)\"", oneOf(values))
    ]
}

private func conditionWarnings(_ context: CheckContext, _ entry: ConditionEntry) -> [DefinitionIssue] {
    guard conditionErrors(context, entry).isEmpty, let field = entry.condition.field,
        let name = entry.condition.operatorName, let target = context.target(field, group: entry.group)
    else { return [] }
    return valueIssue(target.field, name, entry.condition.operand(name), "\(entry.path)/\(name)")
}

private func optionWarnings(_ entry: FieldEntry) -> [DefinitionIssue] {
    let field = entry.field
    guard ["select", "radio", "multiselect"].contains(field.type) else { return [] }
    guard let options = field.options else {
        return field.hasOptionsFrom
            ? []
            : [
                warning(
                    "missing-options", "\(entry.path)/options", "the \(field.type) field \"\(field.key)\" has no options",
                    "Add \"options\" or \"optionsFrom\"")
            ]
    }
    let values = options.compactMap(\.value)
    guard let defaultValue = field.defaultValue, !values.isEmpty, !field.hasOptionsFrom else { return [] }
    let defaults = field.type == "multiselect" ? defaultValue.arrayValue ?? [defaultValue] : [defaultValue]
    guard let missing = defaults.first(where: { item in !values.contains { strictEquals(.string($0), item) } }) else { return [] }
    return [
        warning(
            "default-not-in-options", "\(entry.path)/defaultValue", "\(jsonStringify(missing)) is not an option of \"\(field.key)\"",
            oneOf(values))
    ]
}

private func ruleWarnings(_ context: CheckContext, _ entry: FieldEntry) -> [DefinitionIssue] {
    let field = entry.field
    let rules = field.validation?.json ?? JSONObject()
    let rule = { (name: String, problem: String, hint: String) in
        warning("rule-not-applicable", "\(entry.path)/validation/\(name)", problem, hint)
    }
    let items = field.isGroup
    let known = items || builtInTypes.contains(field.type)
    let numeric = numberTypes.contains(field.type)
    let ranges = known && !numeric ? ["min", "max"].filter { rules.has($0) } : []
    let sized = known && (numberTypes + booleanTypes).contains(field.type) ? ["minLength", "maxLength"].filter { rules.has($0) } : []
    var issues = ranges.map {
        rule($0, "\"\($0)\" applies to number fields only", "Use \($0)Length to limit \(items ? "the number of items" : "text length")")
    }
    issues += sized.map {
        rule($0, "\"\($0)\" does not apply to \(field.type) fields", numeric ? "Use min and max for numbers" : "Remove \($0)")
    }
    issues += itemLimitWarnings(entry)
    if let pattern = rules["pattern"]?.stringValue, let slow = slowPattern(pattern) {
        let (problem, hint) = slowPatternTexts(slow)
        issues.append(
            warning(
                "slow-pattern", "\(entry.path)/validation/pattern", "the pattern of \"\(field.key)\" \(problem) and can be very slow",
                hint))
    }
    if let validator = rules["validator"]?.stringValue, let validators = context.validators, !validators.contains(validator) {
        issues.append(
            warning(
                "unknown-validator", "\(entry.path)/validation/validator", "the validator \"\(validator)\" is not registered",
                "Pass it in the \"validators\" option"))
    }
    return issues
}

private func fieldWarnings(_ context: CheckContext, _ entry: FieldEntry) -> [DefinitionIssue] {
    let field = entry.field
    let custom = !builtInTypes.contains(field.type) && field.type != "group"
    let named = field.type.contains("-") || field.type.contains(":")
    let spelled = field.type.filter { !"-_:".contains($0) }
    let match =
        !custom ? nil : named ? builtInTypes.first { sameText($0, spelled) } : closest(field.type, builtInTypes + ["group", "section"])
    let problem = "\"\(field.type)\" is not a built-in field type"
    var issues: [DefinitionIssue] = []
    if let match {
        issues.append(
            warning("unknown-field-type", "\(entry.path)/type", problem, "Use \"\(match)\", or register a component for \"\(field.type)\""))
    } else if custom && !named {
        issues.append(
            warning(
                "custom-type-name", "\(entry.path)/type", problem,
                "Name custom types with a dash or colon, like \"x-rating\", so a future built-in type cannot take the name"))
    }
    issues += optionWarnings(entry) + ruleWarnings(context, entry) + sourceWarnings(entry) + autocompleteWarnings(entry)
    for (index, key) in (field.optionsDependsOn ?? []).enumerated() {
        issues += missingTarget(context, key, "\(entry.path)/optionsDependsOn/\(index)").map { $0.withSeverity(.warning) }
    }
    return issues
}

private func routeWarnings(_ context: CheckContext) -> [DefinitionIssue] {
    let steps = context.definition.steps ?? []
    return steps.enumerated().flatMap { index, step -> [DefinitionIssue] in
        var issues: [DefinitionIssue] = []
        var targets: [String] = []
        for route in step.routes ?? [] {
            if let to = route.to, !targets.containsText(to) { targets.append(to) }
        }
        for target in targets {
            let position = steps.firstIndex { sameText($0.id, target) } ?? -1
            let sibling = steps.indices.contains(position + 1) ? steps[position + 1] : nil
            let exits =
                steps.indices.contains(position)
                && (steps[position].routes ?? []).contains { ($0.show ?? []).isEmpty && ($0.showAny ?? []).isEmpty }
            guard let sibling, targets.containsText(sibling.id), !exits else { continue }
            issues.append(
                warning(
                    "route-fallthrough", "/steps/\(position)",
                    "branch \"\(target)\" from \"\(step.id)\" continues into the sibling branch \"\(sibling.id)\"",
                    "Add an unconditional route on \"\(target)\" to the step where the branches meet"))
        }
        if step.canSkip && (step.next == .hidden || steps.count < 2) {
            issues.append(
                warning(
                    "skip-unreachable", "/steps/\(index)/skip", "step \"\(step.id)\" has \"skip\" but no Continue button or later step",
                    "Remove \"skip\", or remove \"next\": false"))
        }
        return issues
    }
}

func definitionWarnings(_ context: CheckContext) -> [DefinitionIssue] {
    versionWarnings(context) + propertyWarnings(context) + context.conditions.flatMap { conditionWarnings(context, $0) }
        + context.entries.flatMap { fieldWarnings(context, $0) } + routeWarnings(context) + recallWarnings(context)
        + exclusiveWarnings(context)
}

private func slowPatternTexts(_ slow: SlowPattern) -> (problem: String, hint: String) {
    switch slow {
    case .nested: ("nests quantifiers", "Remove the inner or outer quantifier")
    case .adjacent: ("repeats overlapping parts next to each other", "Merge the repeated parts into one")
    case .long: ("is longer than 1000 characters", "Shorten it to 1000 characters or less")
    }
}

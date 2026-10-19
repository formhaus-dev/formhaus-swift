private let listOperators = ["in", "notIn"]
private let comparisons = ["gt", "gte", "lt", "lte"]

private func expectedType(_ field: FormField) -> String? {
    if field.type == "number" { return "number" }
    if booleanTypes.contains(field.type) { return "boolean" }
    return builtInTypes.contains(field.type) && field.type != "multiselect" && field.type != "file" ? "string" : nil
}

private func valueIssue(_ target: FormField, _ name: String, _ operand: JSONValue?, _ path: String) -> [DefinitionIssue] {
    let mismatch = { (problem: String, hint: String) in [warning("condition-value-mismatch", path, problem, hint)] }
    if name == "notEmpty" {
        return operand?.isTruthy == true
            ? []
            : [
                warning(
                    "condition-always-true", path, "\"notEmpty\": false matches every value",
                    "Use \"notEmpty\": true, or remove the condition")
            ]
    }
    if comparisons.contains(name) {
        guard target.type == "multiselect" || booleanTypes.contains(target.type) else { return [] }
        return mismatch(
            "\"\(target.key)\" is a \(target.type) field, so \"\(name)\" never matches it", "Compare a number, text, radio or select field")
    }
    if target.type == "multiselect" {
        let result = name == "neq" || name == "notIn" ? "always" : "never"
        return mismatch(
            "\"\(target.key)\" holds a list of values, so \"\(name)\" \(result) matches it", "Use notEmpty, or a select or radio field")
    }
    let operands: [JSONValue?]
    if listOperators.contains(name), let list = operand?.arrayValue { operands = list } else { operands = [operand] }
    let expected = expectedType(target)
    if let expected, let wrong = operands.first(where: { ($0?.typeName ?? "undefined") != expected }) {
        return mismatch(
            "\(jsonStringify(wrong)) is a \(wrong?.typeName ?? "undefined"), but \"\(target.key)\" holds a \(expected)",
            "Use a \(expected) value")
    }
    guard expected == "string", !target.hasOptionsFrom, let options = target.options, !options.isEmpty else { return [] }
    let values = options.compactMap(\.value)
    guard let missing = operands.first(where: { item in !values.contains { strictEquals(.string($0), item) } }) else { return [] }
    return mismatch("\(jsonStringify(missing)) is not an option of \"\(target.key)\"", oneOf(values))
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

private func unit(_ scalar: Unicode.Scalar) -> UInt16 {
    UInt16(scalar.value)
}

private let repeaters = Set("*+{".utf16)
private let quantifiers = Set("*+?|{".utf16)

private struct GroupScan {
    private var groups: [Bool] = []
    private(set) var closed = false

    mutating func consume(_ chars: [UInt16], at index: Int) -> Int {
        closed = false
        switch chars[index] {
        case unit("\\"):
            return index + 1
        case unit("["):
            return classEnd(chars, from: index + 1)
        case unit("("):
            groups.append(false)
            return index + 1 < chars.count && chars[index + 1] == unit("?") ? index + 1 : index
        case unit(")"):
            closed = groups.popLast() ?? false
            if closed { markInnermost() }
            return index
        case let char where quantifiers.contains(char):
            markInnermost()
            return index
        default:
            return index
        }
    }

    private mutating func markInnermost() {
        if !groups.isEmpty { groups[groups.count - 1] = true }
    }

    private func classEnd(_ chars: [UInt16], from start: Int) -> Int {
        var index = start
        while index < chars.count && chars[index] != unit("]") {
            if chars[index] == unit("\\") { index += 1 }
            index += 1
        }
        return index
    }
}

func slowPattern(_ pattern: String) -> Bool {
    let chars = Array(pattern.utf16)
    guard chars.count <= 1000 else { return false }
    var scan = GroupScan()
    var index = 0
    while index < chars.count {
        if scan.closed && repeaters.contains(chars[index]) { return true }
        index = scan.consume(chars, at: index) + 1
    }
    return false
}

private func ruleWarnings(_ context: CheckContext, _ entry: FieldEntry) -> [DefinitionIssue] {
    let field = entry.field
    let rules = field.validation?.json ?? JSONObject()
    let rule = { (name: String, problem: String, hint: String) in
        warning("rule-not-applicable", "\(entry.path)/validation/\(name)", problem, hint)
    }
    let items = field.isGroup
    let known = items || builtInTypes.contains(field.type)
    let numeric = field.type == "number"
    let ranges = known && !numeric ? ["min", "max"].filter { rules.has($0) } : []
    let sized = known && ["number", "checkbox", "switch"].contains(field.type) ? ["minLength", "maxLength"].filter { rules.has($0) } : []
    var issues = ranges.map {
        rule($0, "\"\($0)\" applies to number fields only", "Use \($0)Length to limit \(items ? "the number of items" : "text length")")
    }
    issues += sized.map {
        rule($0, "\"\($0)\" does not apply to \(field.type) fields", numeric ? "Use min and max for numbers" : "Remove \($0)")
    }
    if let pattern = rules["pattern"]?.stringValue, slowPattern(pattern) {
        issues.append(
            warning(
                "slow-pattern", "\(entry.path)/validation/pattern",
                "the pattern of \"\(field.key)\" nests quantifiers and can be very slow", "Remove the inner or outer quantifier"))
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
    let match = custom ? closest(field.type, builtInTypes + ["group", "section"]) : nil
    let problem = "\"\(field.type)\" is not a built-in field type"
    var issues: [DefinitionIssue] = []
    if let match {
        issues.append(
            warning("unknown-field-type", "\(entry.path)/type", problem, "Use \"\(match)\", or register a component for \"\(field.type)\""))
    } else if custom && !field.type.contains("-") && !field.type.contains(":") {
        issues.append(
            warning(
                "custom-type-name", "\(entry.path)/type", problem,
                "Name custom types with a dash or colon, like \"x-rating\", so a future built-in type cannot take the name"))
    }
    issues += optionWarnings(entry) + ruleWarnings(context, entry) + sourceWarnings(entry)
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

private func versionWarnings(_ context: CheckContext) -> [DefinitionIssue] {
    let parts = (context.definition.formatVersion ?? "1.0").split(separator: ".", omittingEmptySubsequences: false).map {
        Double($0) ?? .nan
    }
    let major = parts[0]
    let minor = parts.count > 1 ? parts[1] : 0
    guard let container = context.nodes.first(where: { $0.node.type == "section" || $0.node.type == "group" }), major == 1, !(minor >= 1)
    else { return [] }
    return [
        warning(
            "outdated-format-version", "/formatVersion", "\(container.path) is a \(container.node.type), which needs format 1.1",
            "Set \"formatVersion\": \"1.1\", so that older versions of @formhaus/core "
                + "reject the definition instead of skipping the fields inside"
        )
    ]
}

func definitionWarnings(_ context: CheckContext) -> [DefinitionIssue] {
    versionWarnings(context) + propertyWarnings(context) + context.conditions.flatMap { conditionWarnings(context, $0) }
        + context.entries.flatMap { fieldWarnings(context, $0) } + routeWarnings(context)
}

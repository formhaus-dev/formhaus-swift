private func operatorIssues(_ condition: ShowCondition, _ path: String) -> [DefinitionIssue] {
    let keys = condition.json.keys.filter { !sameText($0, "field") }
    let unknown = keys.filter { !conditionOperators.containsText($0) }
    var issues = unknown.map {
        error("unknown-operator", "\(path)/\(pointer($0))", "\"\($0)\" is not a condition operator", suggest($0, conditionOperators))
    }
    let count = keys.count - unknown.count
    if count != 1 && !(count == 0 && !unknown.isEmpty) {
        let problem = count > 0 ? "the condition has \(count) operators" : "the condition has no operator"
        issues.append(
            error("condition-operator-count", path, problem, "Use exactly one of: \(conditionOperators.joined(separator: ", "))")
        )
    }
    return issues
}

func missingTarget(_ context: CheckContext, _ name: String, _ path: String, group: String? = nil, key: String? = nil) -> [DefinitionIssue] {
    if context.target(name, group: group) != nil { return [] }
    if let inner = context.scopeOrder.first(where: { context.scopes[$0]?[name] != nil }) {
        return [
            error("group-scope", path, "\"\(name)\" is a field inside the group \"\(inner)\"", "Only fields of the same group can use it")
        ]
    }
    let scoped = group.flatMap { context.scopes[$0]?.keys } ?? []
    let candidates = (scoped + context.keyList).filter { candidate in key.map { !sameText(candidate, $0) } ?? true }
    return [error("unknown-field", path, "\"\(name)\" is not a field key", suggest(name, candidates))]
}

private func referenceIssues(_ context: CheckContext, _ entry: ConditionEntry, _ field: String) -> [DefinitionIssue] {
    guard let target = context.target(field, group: entry.group) else {
        return missingTarget(context, field, "\(entry.path)/field", group: entry.group, key: entry.key)
    }
    if target.group != nil || entry.step < 0 || entry.owner == .action { return [] }
    let isStep = entry.owner == .step
    if target.step < entry.step || (!isStep && target.step == entry.step) { return [] }
    let sameStep = isStep ? "this or a later step" : "a later step"
    let allowed = isStep ? "earlier steps" : "this or an earlier step"
    let owner = entry.owner == .route ? "Route" : isStep ? "Step" : "Field"
    return [
        error(
            "forward-reference", "\(entry.path)/field", "\"\(field)\" belongs to \(sameStep)",
            "\(owner) conditions can use fields of \(allowed)")
    ]
}

func conditionErrors(_ context: CheckContext, _ entry: ConditionEntry) -> [DefinitionIssue] {
    guard let field = entry.condition.field else {
        return [error("missing-property", entry.path, "missing required property \"field\"", "Add the key of the field to test")]
    }
    return operatorIssues(entry.condition, entry.path) + referenceIssues(context, entry, field)
}

func conditionIssues(_ context: CheckContext) -> [DefinitionIssue] {
    context.conditions.flatMap { conditionErrors(context, $0) }
}

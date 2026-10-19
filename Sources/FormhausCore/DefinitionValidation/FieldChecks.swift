public let sourceNames = ["referrer", "page", "pageTitle", "language", "timezone", "device", "country"]

private func rangeIssue(_ rules: FieldValidation, _ path: String, _ min: String, _ max: String) -> [DefinitionIssue] {
    guard let low = rules.json[min]?.numberValue, let high = rules.json[max]?.numberValue, low > high else { return [] }
    return [
        error("invalid-range", "\(path)/validation/\(min)", "\(min) (\(jsNumberString(low))) is greater than \(max) (\(jsNumberString(high)))", "Lower \(min) or raise \(max)"),
    ]
}

private func patternIssue(_ pattern: String?, _ path: String) -> [DefinitionIssue] {
    guard let pattern, JSRegex(pattern) == nil else { return [] }
    return [
        error("invalid-pattern", "\(path)/validation/pattern", "\(quoteJSON(pattern)) is not a valid regular expression", "Fix the pattern or escape special characters with a backslash"),
    ]
}

private func ruleIssues(_ context: CheckContext, _ entry: FieldEntry) -> [DefinitionIssue] {
    let field = entry.field
    let path = entry.path
    let rules = field.validation ?? FieldValidation(json: JSONObject())
    let items = field.isGroup ? field.defaultItems : nil
    var issues = rangeIssue(rules, path, "minLength", "maxLength") + rangeIssue(rules, path, "min", "max") + patternIssue(rules.pattern, path)
    if let match = rules.matchField {
        issues += missingTarget(context, match, "\(path)/validation/matchField", group: entry.group?.key)
    }
    if let items, let max = rules.maxLength, items > max {
        issues.append(error("invalid-range", "\(path)/defaultItems", "defaultItems (\(jsNumberString(items))) is greater than maxLength (\(jsNumberString(max)))", "Lower defaultItems or raise maxLength"))
    }
    return issues
}

private func optionIssues(_ entry: FieldEntry) -> [DefinitionIssue] {
    let values = (entry.field.options ?? []).map(\.value)
    return values.enumerated().flatMap { index, value -> [DefinitionIssue] in
        guard let first = values.firstIndex(where: { $0?.utf16.elementsEqual(value?.utf16 ?? "".utf16) ?? (value == nil) }), first < index else { return [] }
        return [error("duplicate-option-value", "\(entry.path)/options/\(index)/value", "\"\(value ?? "")\" is already an option value")]
    }
}

func fieldIssues(_ context: CheckContext) -> [DefinitionIssue] {
    context.entries.flatMap { ruleIssues(context, $0) + optionIssues($0) }
}

private let queryHint = "Use { \"query\": \"<parameter name>\" } for a URL parameter"

func sourceIssues(_ context: CheckContext) -> [DefinitionIssue] {
    context.entries.flatMap { entry -> [DefinitionIssue] in
        guard let source = entry.field.source else { return [] }
        let at = "\(entry.path)/source"
        if let name = source.stringValue {
            if sourceNames.containsText(name) { return [] }
            let hint = name == "query" ? queryHint : suggest(name, sourceNames) ?? oneOf(sourceNames)
            return [error("unknown-source", at, "\"\(name)\" is not a source", hint)]
        }
        if let object = source.objectValue, object.count == 1, let query = object["query"]?.stringValue, !query.isBlankText { return [] }
        return [error("invalid-type", at, "must be a source name or a query object", queryHint)]
    }
}

func sourceWarnings(_ entry: FieldEntry) -> [DefinitionIssue] {
    guard entry.field.source != nil, entry.field.type != "hidden" else { return [] }
    return [warning("source-not-applicable", "\(entry.path)/source", "only hidden fields read \"source\"", "Set \"type\" to \"hidden\" or remove \"source\"")]
}

private func nodeId(_ entry: FieldEntry) -> String {
    entry.group.map { "\($0.key).\(entry.field.key)" } ?? entry.field.key
}

private func dependencyGraph(_ context: CheckContext) -> (keys: [String], edges: StringMap<[String]>) {
    var keys: [String] = []
    var edges = StringMap<[String]>()
    func link(_ owners: [String], _ source: Conditional, _ group: String? = nil) {
        let known = source.conditionFields.compactMap { context.target($0, group: group).map(nodeId) }
        guard !known.isEmpty else { return }
        for owner in owners {
            if edges[owner] == nil { keys.append(owner) }
            edges[owner, default: []] += known
        }
    }
    for entry in context.entries { link([nodeId(entry)], entry.field, entry.group?.key) }
    for entry in context.nodes where entry.group == nil {
        if let section = entry.node.section { link(section.fields.map(\.key), section) }
    }
    for step in context.definition.steps ?? [] { link(valueFields(step.fields).map(\.key), step) }
    return (keys, edges)
}

private func findCycles(_ keys: [String], _ graph: StringMap<[String]>) -> [[String]] {
    var visiting = StringMap<Bool>()
    var cycles: [[String]] = []
    for start in keys where visiting[start] == nil {
        visiting[start] = true
        var stack: [(String, Int)] = [(start, 0)]
        while let frame = stack.last {
            let neighbors = graph[frame.0] ?? []
            stack[stack.count - 1].1 += 1
            guard frame.1 < neighbors.count else {
                visiting[frame.0] = false
                stack.removeLast()
                continue
            }
            let neighbor = neighbors[frame.1]
            if visiting[neighbor] == true {
                let nodes = stack.map(\.0)
                cycles.append(Array(nodes[nodes.firstIndex { sameText($0, neighbor) }!...]) + [neighbor])
            } else if visiting[neighbor] == nil {
                visiting[neighbor] = true
                stack.append((neighbor, 0))
            }
        }
    }
    return cycles
}

func graphIssues(_ context: CheckContext) -> [DefinitionIssue] {
    var paths = StringMap<String>()
    for entry in context.entries { paths[nodeId(entry)] = entry.path }
    let (keys, edges) = dependencyGraph(context)
    return findCycles(keys, edges).map { cycle in
        error("condition-cycle", paths[cycle[0]] ?? "", "show conditions form a cycle: \(cycle.joined(separator: " -> "))", "Remove one of the conditions in the cycle")
    }
}

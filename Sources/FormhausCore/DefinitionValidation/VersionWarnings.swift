let containsOperators = ["contains", "notContains"]

private let upgrade = "Upgrade the server that runs validateSubmission() first"

private func latestOutdated(_ context: CheckContext) -> (problem: String, needed: Int, hint: String)? {
    if let recall = recallTexts(context).first(where: { !$0.keys.isEmpty }), let key = recall.keys.first {
        return ("\(recall.path) recalls \"{{\(key)}}\"", 5, "Below 1.5 the text shows the braces as written")
    }
    if let entry = context.entries.first(where: { ($0.field.options ?? []).contains(where: \.exclusive) }) {
        return ("\(entry.path) has an exclusive option", 5, "Older versions of @formhaus/core ignore \"exclusive\". \(upgrade)")
    }
    if let entry = context.entries.first(where: { $0.field.autocomplete != nil }) {
        return (
            "\(entry.path)/autocomplete is set", 5, "Older versions of @formhaus/core report \"autocomplete\" as an unknown property"
        )
    }
    return nil
}

private func outdated(_ context: CheckContext, _ minor: Double) -> (problem: String, needed: Int, hint: String)? {
    if minor < 5, let latest = latestOutdated(context) { return latest }
    if minor < 4, let entry = context.conditions.first(where: { entry in containsOperators.contains { entry.condition.json.has($0) } }),
        let name = containsOperators.first(where: { entry.condition.json.has($0) })
    {
        return ("\(entry.path) uses \"\(name)\"", 4, "Older versions of @formhaus/core reject this operator. \(upgrade)")
    }
    if minor < 3, let scale = context.nodes.first(where: { scaleTypes.contains($0.node.type) }) {
        let hint = "Older versions of @formhaus/core treat this type as a custom type and do not validate it. \(upgrade)"
        return ("\(scale.path) is a \(scale.node.type)", 3, hint)
    }
    return context.nodes.first { $0.node.type == "section" || $0.node.type == "group" }.map {
        (
            "\($0.path) is a \($0.node.type)", 1,
            "so that older versions of @formhaus/core reject the definition instead of skipping the fields inside"
        )
    }
}

func versionWarnings(_ context: CheckContext) -> [DefinitionIssue] {
    let (major, minor) = formatParts(context.definition.json["formatVersion"])
    guard let (problem, needed, hint) = outdated(context, minor), major == 1, !(minor >= Double(needed)) else { return [] }
    let text = "Set \"formatVersion\": \"1.\(needed)\"\(needed > 1 ? "." : ",") \(hint)"
    return [warning("outdated-format-version", "/formatVersion", "\(problem), which needs format 1.\(needed)", text)]
}

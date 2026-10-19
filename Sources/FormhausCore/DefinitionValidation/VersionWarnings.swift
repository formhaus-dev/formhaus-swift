let containsOperators = ["contains", "notContains"]

private func versionParts(_ version: String?) -> (major: Double, minor: Double) {
    let parts = (version ?? "1.0").split(separator: ".", omittingEmptySubsequences: false).map { Double($0) ?? .nan }
    return (parts[0], parts.count > 1 ? parts[1] : 0)
}

private func outdated(_ context: CheckContext, _ minor: Double) -> (problem: String, needed: Int)? {
    if minor < 4, let entry = context.conditions.first(where: { entry in containsOperators.contains { entry.condition.json.has($0) } }),
        let name = containsOperators.first(where: { entry.condition.json.has($0) })
    {
        return ("\(entry.path) uses \"\(name)\"", 4)
    }
    if minor < 3, let scale = context.nodes.first(where: { scaleTypes.contains($0.node.type) }) {
        return ("\(scale.path) is a \(scale.node.type)", 3)
    }
    return context.nodes.first { $0.node.type == "section" || $0.node.type == "group" }.map { ("\($0.path) is a \($0.node.type)", 1) }
}

func versionWarnings(_ context: CheckContext) -> [DefinitionIssue] {
    let (major, minor) = versionParts(context.definition.formatVersion)
    guard let (problem, needed) = outdated(context, minor), major == 1, !(minor >= Double(needed)) else { return [] }
    let hint =
        needed > 1
        ? "Set \"formatVersion\": \"1.\(needed)\". Older versions of @formhaus/core "
            + (needed > 3 ? "reject this operator" : "treat this type as a custom type and do not validate it")
            + ". Upgrade the server that runs validateSubmission() first"
        : "Set \"formatVersion\": \"1.1\", so that older versions of @formhaus/core "
            + "reject the definition instead of skipping the fields inside"
    return [warning("outdated-format-version", "/formatVersion", "\(problem), which needs format 1.\(needed)", hint)]
}

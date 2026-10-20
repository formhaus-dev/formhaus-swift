private func exclusiveIssues(_ field: FormField, _ path: String, _ exclusive: [JSONValue]) -> [DefinitionIssue] {
    let options = field.options ?? []
    let first = options.firstIndex(where: \.exclusive) ?? options.endIndex
    var issues: [DefinitionIssue] = []
    if options[first...].contains(where: { !$0.exclusive }) {
        issues.append(
            warning("exclusive-option-position", "\(path)/options/\(first)", "exclusive options of \"\(field.key)\" are not last"))
    }
    let defaults = field.defaultValue?.arrayValue ?? []
    if defaults.count > 1, defaults.contains(where: { value in exclusive.contains { sameValueZero($0, value) } }) {
        issues.append(
            warning(
                "exclusive-default-value", "\(path)/defaultValue",
                "the default of \"\(field.key)\" mixes exclusive and other options"))
    }
    if (field.validation?.minLength ?? 0) > 1 {
        issues.append(
            warning(
                "exclusive-with-min-length", "\(path)/validation/minLength",
                "\"minLength\" does not apply to an exclusive option of \"\(field.key)\""))
    }
    return issues
}

func exclusiveWarnings(_ context: CheckContext) -> [DefinitionIssue] {
    context.entries.flatMap { entry -> [DefinitionIssue] in
        let field = entry.field
        let exclusive = exclusiveValues(field)
        guard exclusive.isEmpty else { return exclusiveIssues(field, entry.path, exclusive) }
        return (field.options ?? []).enumerated().compactMap { index, option in
            option.exclusive
                ? warning(
                    "exclusive-not-applicable", "\(entry.path)/options/\(index)/exclusive",
                    "\"\(field.key)\" is not a multiselect with static options")
                : nil
        }
    }
}

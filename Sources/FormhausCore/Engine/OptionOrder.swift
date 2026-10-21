@MainActor
private var reportedUnordered = false

@MainActor
func unorderedWarning(_ definition: FormDefinition, _ options: FormEngineOptions) -> [DefinitionIssue] {
    guard !reportedUnordered, options.research == nil,
        definition.allFields.contains(where: { $0.randomize || $0.items.contains(where: \.randomize) })
    else { return [] }
    reportedUnordered = true
    return [
        warning(
            "missing-research", "", "\"randomize\" needs the research module, so the options show in written order",
            "Pass Research() from FormhausResearch")
    ]
}

@_spi(Renderer)
public func optionKey(group: String, field: String) -> String {
    "\(group).\(field)"
}

extension FormEngine {
    @_spi(Renderer)
    public func optionKey(_ key: String) -> String {
        core.visibility.parse(key).map { FormhausCore.optionKey(group: $0.group, field: $0.field) } ?? key
    }

    public func orderOptions(_ key: String, options: [FieldOption]? = nil) -> [FieldOption] {
        let visibility = core.visibility
        let values = core.values.json
        let name = optionKey(key)
        let field =
            visibility.fieldOf(name, values)
            ?? visibility.groups.lazy.compactMap { owner in
                visibility.fieldOf(owner.key, values)?.ordinal == owner.ordinal
                    ? owner.items.first { sameText(FormhausCore.optionKey(group: owner.key, field: $0.key), name) } : nil
            }.first
        let source = options ?? field?.options ?? []
        guard let research = self.options.research, let field, field.randomize, randomizedTypes.contains(field.type),
            visibility.index.section(of: field)?.isMatrix != true
        else { return source }
        return research.order(seed: seed, key: name, options: source)
    }
}

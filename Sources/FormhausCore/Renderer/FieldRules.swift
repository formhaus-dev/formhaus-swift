@_spi(Renderer)
public struct FieldRules: Sendable, Hashable {
    public let readOnly: Bool
    public let disabled: [Bool]

    public func isDisabled(_ index: Int) -> Bool {
        disabled.indices.contains(index) && disabled[index]
    }
}

private func ruleConditions(_ field: FormField, _ options: [FieldOption]) -> [ShowCondition] {
    ([field.readOnly] + options.map(\.disabled)).flatMap { rule -> [ShowCondition] in
        if case .conditions(let list)? = rule { return list }
        return []
    }
}

extension FormEngine {
    private func ruleScope(_ key: String) -> JSONObject {
        let visibility = core.visibility
        let values = visibility.conditionValues(core.values.json)
        guard let path = visibility.parse(key), let group = visibility.groups.first(where: { sameText($0.key, path.group) }) else {
            return values
        }
        let items = itemsOf(core.values[group.key])
        return itemScope(group, items.indices.contains(path.index) ? items[path.index] : .null, values)
    }

    @_spi(Renderer)
    public func fieldRules(_ field: FormField, options: [FieldOption], at key: String? = nil) -> FieldRules {
        guard field.readOnly != nil || options.contains(where: { $0.disabled != nil }) else {
            return FieldRules(readOnly: false, disabled: [])
        }
        let scope = ruleScope(key ?? field.key)
        let limits = core.visibility.limits(core.values.json)
        return FieldRules(
            readOnly: field.readOnly?.isMet(scope, limits: limits) == true,
            disabled: options.map { $0.disabled?.isMet(scope, limits: limits) == true })
    }

    @_spi(Renderer)
    public func ruleDependencies(_ field: FormField, options: [FieldOption], at key: String? = nil) -> [RecallDependency] {
        let names = ruleConditions(field, options).compactMap(\.field)
        guard !names.isEmpty else { return [] }
        let visibility = core.visibility
        let path = key.flatMap(visibility.parse)
        let items = path.flatMap { path in visibility.groups.first { sameText($0.key, path.group) } }?.items ?? []
        var seen = Set<RecallDependency>()
        return names.compactMap { name in
            let dependency: RecallDependency
            if let path, items.contains(where: { sameText($0.key, name) }) {
                dependency = RecallDependency(key: "\(path.group).\(path.index).\(name)", isGroup: false)
            } else {
                dependency = RecallDependency(key: name, isGroup: visibility.groups.contains { sameText($0.key, name) })
            }
            return seen.insert(dependency).inserted ? dependency : nil
        }
    }
}

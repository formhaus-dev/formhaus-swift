public struct RecallDependency: Sendable, Hashable {
    public let key: String
    public let isGroup: Bool
}

extension FormEngine {
    private func dependencies(_ texts: [String?], _ item: RecallItem?) -> [RecallDependency] {
        guard definition.recallsAnswers else { return [] }
        let keys = texts.compactMap(\.self).filter(hasRecallBraces).flatMap(recallKeys)
        guard !keys.isEmpty else { return [] }
        let scope = item.flatMap { item in core.visibility.groups.first { sameText($0.key, item.group) } }?.items ?? []
        var seen = Set<RecallDependency>()
        return keys.compactMap { key in
            let dependency: RecallDependency
            if let item, scope.contains(where: { sameText($0.key, key) }) {
                dependency = RecallDependency(key: "\(item.group).\(item.index).\(key)", isGroup: false)
            } else {
                dependency = RecallDependency(key: key, isGroup: core.visibility.groups.contains { sameText($0.key, key) })
            }
            return seen.insert(dependency).inserted ? dependency : nil
        }
    }

    private func slotTexts(_ json: JSONObject, skipping skipped: String? = nil) -> [String?] {
        recallSlots.filter { $0 != skipped }.map { json[$0]?.stringValue }
    }

    @_spi(Renderer)
    public func recallDependencies(_ field: FormField, at key: String? = nil) -> [RecallDependency] {
        let item = key.flatMap(core.visibility.parse).map { RecallItem(group: $0.group, index: $0.index) }
        return dependencies(slotTexts(field.json, skipping: "itemLabel"), item)
    }

    @_spi(Renderer)
    public func recallDependencies(_ section: FormSection) -> [RecallDependency] {
        dependencies(slotTexts(section.json), nil)
    }

    @_spi(Renderer)
    public func recallDependencies(_ step: FormStep) -> [RecallDependency] {
        dependencies(slotTexts(step.json), nil)
    }

    @_spi(Renderer)
    public func itemTitleDependencies(_ group: FormField, _ index: Int) -> [RecallDependency] {
        dependencies([group.label], nil) + dependencies([group.itemLabel], RecallItem(group: group.key, index: index))
    }
}

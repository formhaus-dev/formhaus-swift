private struct ReconciledItem {
    let item: JSONValue
    let cleared: [String]
    let stable: Bool
}

extension VisibilityState {
    private func reconcileItem(_ fields: [FormField], _ item: JSONValue, _ id: Int?, _ scope: JSONObject, _ limits: ListLimits)
        -> ReconciledItem
    {
        guard var entry = item.objectValue else { return ReconciledItem(item: item, cleared: [], stable: true) }
        var cleared: [String] = []
        for _ in 0...fields.count {
            let inner = itemScope(fields, .object(entry), scope)
            let shown = fields.filter { isVisible($0, inner, limits: limits) }
            let visible = Set(shown.map(\.ordinal))
            let hidden = fields.filter { field in !visible.contains(field.ordinal) && entry[field.key] != nil }
            var restored = JSONObject()
            for field in shown where entry[field.key] == nil {
                if let value = starts.itemStartValue(id, field.key) { restored[field.key] = value }
            }
            if hidden.isEmpty && restored.isEmpty { return ReconciledItem(item: .object(entry), cleared: cleared, stable: true) }
            let previous = entry
            entry.merge(restored)
            for field in hidden {
                if let value = previous[field.key] { starts.rememberItem(id, field.key, value) }
                entry.removeValue(forKey: field.key)
            }
            cleared += hidden.map(\.key) + restored.keys
        }
        return ReconciledItem(item: .object(entry), cleared: cleared, stable: false)
    }

    func reconcileItems(_ values: inout Values, _ errors: inout FieldErrors, _ cleared: inout KeySet) {
        for group in groups where activeField(group.key, values.json)?.ordinal == group.ordinal {
            let source = itemsOf(values[group.key])
            let ids = values.itemIds(group.key)
            let scope = scope(values.json)
            let limits = limits(values.json)
            let fields = group.items
            let context = reconciled.context(group, scope, limits, epoch: starts.itemEpoch)
            let (items, reused) = reconciled.map(group, source, ids: ids, context: context) { position, item in
                let result = reconcileItem(fields, item, ids.indices.contains(position) ? ids[position] : nil, scope, limits)
                for key in result.cleared { cleared.insert(itemPath(group.key, position, key)) }
                return (result.item, result.stable && result.cleared.isEmpty)
            }
            if reused { continue }
            if items != source {
                values.set(group.key, ValueSlot(.array(items), ref: Ref(token: freshToken(), items: ids)))
            }
            dropHiddenErrors(group, items, values.json, &errors, &cleared)
        }
    }

    private func dropHiddenErrors(
        _ group: FormField, _ items: [JSONValue], _ values: JSONObject, _ errors: inout FieldErrors, _ cleared: inout KeySet
    ) {
        guard !errors.isEmpty else { return }
        let fields = group.items
        let scope = scope(values)
        let limits = limits(values)
        var shown: [Int: KeySet] = [:]
        for key in errors.keys {
            guard let (position, field) = splitPath(group.key, key) else { continue }
            if position < items.count {
                let keys =
                    shown[position]
                    ?? KeySet(fields.filter { isVisible($0, itemScope(fields, items[position], scope), limits: limits) }.map(\.key))
                shown[position] = keys
                if keys.contains(field) { continue }
            }
            errors.removeValue(forKey: key)
            cleared.insert(key)
        }
    }
}

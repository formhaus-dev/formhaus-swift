extension VisibilityState {
    private func reconcileItem(_ group: FormField, _ item: JSONValue, _ id: Int?, _ values: JSONObject) -> (
        item: JSONValue, cleared: [String]
    ) {
        guard var entry = item.objectValue else { return (item, []) }
        var cleared: [String] = []
        for _ in 0...group.items.count {
            let shown = itemFields(group, .object(entry), values)
            let hidden = group.items.filter { field in !shown.contains { $0.ordinal == field.ordinal } && entry[field.key] != nil }
            var restored = JSONObject()
            for field in shown where entry[field.key] == nil {
                if let value = starts.itemStartValue(id, field.key) { restored[field.key] = value }
            }
            if hidden.isEmpty && restored.isEmpty { break }
            let previous = entry
            entry.merge(restored)
            for field in hidden {
                if let value = previous[field.key] { starts.rememberItem(id, field.key, value) }
                entry.removeValue(forKey: field.key)
            }
            cleared += hidden.map(\.key) + restored.keys
        }
        return (.object(entry), cleared)
    }

    func reconcileItems(_ values: inout Values, _ errors: inout FieldErrors, _ cleared: inout KeySet) {
        for group in groups where activeField(group.key, values.json)?.ordinal == group.ordinal {
            let slot = values.slot(group.key)
            let source = itemsOf(slot.value)
            let ids = values.itemIds(group.key)
            let json = values.json
            let items = source.enumerated().map { position, item in
                let reconciled = reconcileItem(group, item, ids.indices.contains(position) ? ids[position] : nil, json)
                for key in reconciled.cleared { cleared.insert(itemPath(group.key, position, key)) }
                return reconciled.item
            }
            if items != source {
                values.set(group.key, ValueSlot(.array(items), ref: Ref(token: freshToken(), items: ids)))
            }
            for key in errors.keys {
                guard let (position, field) = splitPath(group.key, key) else { continue }
                if position < items.count, itemFields(group, items[position], values.json).contains(where: { sameText($0.key, field) }) {
                    continue
                }
                errors.removeValue(forKey: key)
                cleared.insert(key)
            }
        }
    }
}

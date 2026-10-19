extension VisibilityState {
    private func reconcileItem(
        _ group: FormField, _ item: JSONValue, _ id: Int?, _ position: Int, _ values: JSONObject, _ cleared: inout KeySet
    ) -> JSONValue {
        guard var entry = item.objectValue else { return item }
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
            for key in hidden.map(\.key) + restored.keys { cleared.insert(itemPath(group.key, position, key)) }
        }
        return .object(entry)
    }

    func reconcileItems(_ values: inout Values, _ errors: inout FieldErrors, _ cleared: inout KeySet) {
        for group in groups where activeField(group.key, values.json)?.ordinal == group.ordinal {
            let slot = values.slot(group.key)
            let source = itemsOf(slot.value)
            let ids = values.itemIds(group.key)
            let json = values.json
            let items = source.enumerated().map { position, item in
                reconcileItem(group, item, ids.indices.contains(position) ? ids[position] : nil, position, json, &cleared)
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

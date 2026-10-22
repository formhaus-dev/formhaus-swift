extension VisibilityState {
    func withKept(_ values: Values, skipped: [String]) -> Values {
        guard keep else { return values }
        var result = values
        for key in index.fieldsByKey.keys where result[key] == nil && !skipped.containsText(key) && activeField(key, values.json) == nil {
            if let field = index.fieldsByKey[key]?.first { result.set(key, starts.startValue(field)) }
        }
        for group in groups where !skipped.containsText(group.key) {
            guard let items = result[group.key]?.arrayValue else { continue }
            let ids = result.itemIds(group.key)
            let filled = keptItems(group, items, ids)
            if filled != items { result.set(group.key, ValueSlot(.array(filled), ref: Ref(token: freshToken(), items: ids))) }
        }
        return result
    }

    private func keptItems(_ group: FormField, _ items: [JSONValue], _ ids: [Int]) -> [JSONValue] {
        items.enumerated().map { position, item in
            guard var entry = item.objectValue else { return item }
            let id = ids.indices.contains(position) ? ids[position] : nil
            for field in group.items where entry[field.key] == nil {
                if let value = starts.itemStartValue(id, field.key) { entry[field.key] = value }
            }
            return .object(entry)
        }
    }
}

extension EngineCore {
    func keptValues() -> Values {
        visibility.withKept(values, skipped: skipped.flatMap(\.keys))
    }

    func addKept(_ result: inout JSONObject) {
        let kept = keptValues().json
        for field in visibility.allFields {
            guard let value = kept[field.key], let owner = visibility.fieldOf(field.key, values.json) else { continue }
            result[field.key] = owner.isGroup ? cleanItems(owner, value, JSONObject(), .standard, all: true) : trimValue(owner, value)
        }
    }
}

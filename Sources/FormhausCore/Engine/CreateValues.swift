func createItem(_ fields: [FormField], _ source: JSONObject? = nil) -> JSONObject {
    createValues(fields, source.map { Values(fresh: $0) }).json
}

func createValues(
    _ fields: [FormField], _ initialValues: Values? = nil, pick: (String, JSONObject) -> FormField? = { _, _ in nil }
) -> Values {
    var byKey = StringMap<[FormField]>()
    for field in fields { byKey[field.key, default: []].append(field) }
    var values = Values()
    func fill(_ field: FormField) {
        values.remove(field.key)
        if let value = field.defaultValue {
            values.set(field.key, ValueSlot(value, ref: Ref.preset(value, field.ordinal)))
        } else if field.isGroup, let count = field.defaultItems, count > 0 {
            let length = Int(max(0, min(count, field.itemLimits.max)))
            let items = (0..<length).map { _ in JSONValue.object(createItem(field.items)) }
            values.set(field.key, .fresh(.array(items)))
        }
    }
    let source = initialValues ?? Values()
    for field in fields where byKey[field.key]?.last?.ordinal == field.ordinal { fill(field) }
    for key in source.keys where !sameText(key, "__proto__") { values.set(key, source.slot(key)) }
    var expanded = KeySet()
    for field in fields {
        let key = field.key
        guard let same = byKey[key] else { continue }
        let shared = same.count > 1
        let chosen = (shared ? pick(key, values.json) : nil) ?? same[0]
        let items = values.slot(key)
        if !source.has(key) {
            values.remove(key)
            if shared {
                fill(chosen)
            } else if items.value != nil {
                values.set(key, items)
            }
        } else if chosen.isGroup, !expanded.contains(key), let list = items.value?.arrayValue {
            expanded.insert(key)
            let mapped = list.map { item in item.objectValue.map { JSONValue.object(createItem(chosen.items, $0)) } ?? item }
            let ids = items.ref?.items ?? []
            let itemIds = ids.count == list.count ? ids : list.map { _ in freshToken() }
            values.set(key, ValueSlot(.array(mapped), ref: Ref(token: freshToken(), items: itemIds)))
        }
    }
    return values
}

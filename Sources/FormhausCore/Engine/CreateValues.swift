func createValues(
    _ fields: [FormField], _ initialValues: JSONObject? = nil, pick: (String, JSONObject) -> FormField? = { _, _ in nil }
) -> JSONObject {
    var byKey = StringMap<[FormField]>()
    for field in fields { byKey[field.key, default: []].append(field) }
    var values = JSONObject()
    func fill(_ field: FormField) {
        values.removeValue(forKey: field.key)
        if let value = field.defaultValue {
            values[field.key] = value
        } else if field.isGroup, let count = field.defaultItems, count > 0 {
            let item = JSONValue.object(createValues(field.items))
            values[field.key] = .array(Array(repeating: item, count: Int(min(count, 1e6))))
        }
    }
    let source = initialValues ?? JSONObject()
    for field in fields where byKey[field.key]?.last === field { fill(field) }
    for (key, value) in source where !sameText(key, "__proto__") { values[key] = value }
    var expanded = KeySet()
    for field in fields {
        let key = field.key
        let same = byKey[key]!
        let shared = same.count > 1
        let chosen = (shared ? pick(key, values) : nil) ?? same[0]
        let items = values[key]
        if !source.has(key) {
            values.removeValue(forKey: key)
            if shared {
                fill(chosen)
            } else if let items {
                values[key] = items
            }
        } else if chosen.isGroup, !expanded.contains(key), let list = items?.arrayValue {
            expanded.insert(key)
            values[key] = .array(list.map { item in item.objectValue.map { .object(createValues(chosen.items, $0)) } ?? item })
        }
    }
    return values
}

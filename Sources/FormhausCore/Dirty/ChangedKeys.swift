func sameValue(_ lhs: JSONValue?, _ rhs: JSONValue?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil), (.null?, .null?): true
    case (.bool(let a)?, .bool(let b)?): a == b
    case (.number(let a)?, .number(let b)?): a == b
    case (.string(let a)?, .string(let b)?): sameText(a, b)
    case (.array(let a)?, .array(let b)?): a.count == b.count && zip(a, b).allSatisfy(sameValue)
    case (.object(let a)?, .object(let b)?): a.count == b.count && a.allSatisfy { sameValue($0.value, b[$0.key]) }
    default: false
    }
}

private func entries(_ value: JSONValue?) -> [JSONObject]? {
    guard let items = value?.arrayValue else { return nil }
    let objects = items.compactMap(\.objectValue)
    return objects.count == items.count ? objects : nil
}

private func unionKeys(_ lhs: JSONObject, _ rhs: JSONObject) -> [String] {
    lhs.keys + rhs.keys.filter { !lhs.has($0) }
}

func changedKeys(_ baseline: JSONObject, _ current: JSONObject) -> [String] {
    var keys: [String] = []
    for key in unionKeys(baseline, current) {
        let before = baseline[key]
        let after = current[key]
        if sameValue(before, after) { continue }
        guard let old = entries(before), let new = entries(after), old.count == new.count else {
            keys.append(key)
            continue
        }
        for (index, (item, next)) in zip(old, new).enumerated() {
            for field in unionKeys(item, next) where !sameValue(item[field], next[field]) { keys.append(itemPath(key, index, field)) }
        }
    }
    return keys.sorted(by: codeUnitLess)
}

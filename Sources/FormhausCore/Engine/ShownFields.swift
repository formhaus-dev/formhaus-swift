struct TrackedGroup {
    let group: FormField
    let fields: [FormField]
}

struct GroupShown {
    let key: String
    let fields: [String]
    let ids: [String]
    let rows: [[Bool]]
}

struct ShownFields {
    let token: Int
    let top: StringMap<(String, Bool)>
    let groups: [GroupShown]

    var flat: StringMap<(String, Bool)> {
        var result = top
        for group in groups {
            for (position, id) in group.ids.enumerated() {
                for (index, field) in group.fields.enumerated() {
                    result["\(group.key) \(id) \(field)"] = (itemPath(group.key, position, field), group.rows[position][index])
                }
            }
        }
        return result
    }
}

final class ShownCache {
    let tracked: [TrackedGroup]
    let incremental: Bool
    let rows = ItemCache<[Bool]>()
    var token = 0

    init(_ index: DefinitionIndex, _ groups: [FormField]) {
        tracked = groups.compactMap { group in
            let fields = group.items.filter(\.isConditioned)
            return fields.isEmpty ? nil : TrackedGroup(group: group, fields: fields)
        }
        incremental = tracked.allSatisfy {
            !index.isShared($0.group.key) && OrderedKeys($0.fields.map(\.key)).keys.count == $0.fields.count
        }
    }
}

extension VisibilityState {
    func trackShown(_ values: Values, since previous: ShownFields?) -> (state: ShownFields, flips: [(String, Bool)]) {
        let cache = shown
        let fast = cache.incremental && previous?.token == cache.token
        var top = StringMap<(String, Bool)>(insertionOrder: true)
        for field in conditional {
            top[field.key] = (field.key, (top[field.key]?.1 ?? false) || visible(field, values.json))
        }
        var flips: [(String, Bool)] = []
        if fast, let previous {
            for (id, entry) in top where previous.top[id].map({ $0.1 == !entry.1 }) == true { flips.append(entry) }
        }
        let groups = cache.tracked.enumerated().map { offset, tracked in
            shownRows(tracked, values, fast ? previous?.groups[offset] : nil, &flips)
        }
        cache.token = freshToken()
        let state = ShownFields(token: cache.token, top: top, groups: groups)
        guard !fast, let previous else { return (state, flips) }
        let before = previous.flat
        return (state, state.flat.compactMap { id, entry in before[id].map { $0.1 == !entry.1 } == true ? entry : nil })
    }

    private func shownRows(_ tracked: TrackedGroup, _ values: Values, _ previous: GroupShown?, _ flips: inout [(String, Bool)])
        -> GroupShown
    {
        let scope = scope(values.json)
        let limits = limits(values.json)
        let key = tracked.group.key
        let items = itemsOf(values[key])
        let fields = tracked.group.items
        let names = tracked.fields.map(\.key)
        let idKey = { (position: Int, item: JSONValue) in
            item.objectValue != nil ? values.itemId(key, position).map { "i\($0)" } ?? "\(position)" : "\(position)"
        }
        var known: [String: Int]?
        let context = shown.rows.context(tracked.group, scope, limits)
        let (rows, reused) = shown.rows.map(tracked.group, items, ids: values.itemIds(key), context: context) { position, item in
            let inner = itemScope(fields, item, scope)
            let row = tracked.fields.map { isVisible($0, inner, limits: limits) }
            guard let previous else { return (row, true) }
            let lookup = known ?? Dictionary(previous.ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            known = lookup
            guard let before = lookup[idKey(position, item)] else { return (row, true) }
            for (index, name) in names.enumerated() where previous.rows[before][index] == !row[index] {
                flips.append((itemPath(key, position, name), row[index]))
            }
            return (row, true)
        }
        if reused, let previous { return previous }
        let keys = items.enumerated().map(idKey)
        return GroupShown(key: key, fields: names, ids: keys, rows: rows)
    }
}

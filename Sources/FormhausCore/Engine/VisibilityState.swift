struct ItemField {
    let group: FormField
    let index: Int
    let field: FormField
}

final class VisibilityState {
    let definition: FormDefinition
    let index: DefinitionIndex
    let groups: [FormField]
    let paths: PathCache
    var starts = StartValues()

    init(_ definition: FormDefinition) {
        self.definition = definition
        index = DefinitionIndex(definition)
        groups = index.allFields.filter(\.isGroup)
        paths = PathCache(definition)
    }

    var allFields: [FormField] { index.allFields }

    func scope(_ values: JSONObject) -> JSONObject { paths.path(values).values }

    func conditionValues(_ values: JSONObject) -> JSONObject { paths.conditionValues(values) }

    func visibleSteps(_ values: JSONObject) -> [FormStep] {
        definition.isMultiStep ? paths.path(values).steps : []
    }

    func visible(_ field: FormField, _ values: JSONObject) -> Bool {
        let active = scope(values)
        let section = index.section(of: field)
        return (section.map { isVisible($0, active) } ?? true) && isVisible(field as Conditional, active)
    }

    func onPath(_ field: FormField, _ values: JSONObject) -> Bool {
        guard let step = index.step(of: field) else { return true }
        return paths.path(values).contains(step)
    }

    func activeField(_ key: String, _ values: JSONObject) -> FormField? {
        index.fieldsByKey[key]?.first { onPath($0, values) && visible($0, values) }
    }

    func parse(_ key: String) -> (group: String, index: Int, field: String)? {
        if index.fieldsByKey.has(key) { return nil }
        for group in groups {
            if let (position, field) = splitPath(group.key, key) { return (group.key, position, field) }
        }
        return nil
    }

    func owner(_ key: String) -> String { parse(key)?.group ?? key }

    func itemFields(_ group: FormField, _ item: JSONValue, _ values: JSONObject) -> [FormField] {
        let scope = itemScope(group, item, scope(values))
        return group.items.filter { isVisible($0 as Conditional, scope) }
    }

    func activeItem(_ key: String, _ values: JSONObject) -> ItemField? {
        guard let (groupKey, position, fieldKey) = parse(key), let group = activeField(groupKey, values), group.isGroup else { return nil }
        let items = itemsOf(values[groupKey])
        guard position < items.count, let field = itemFields(group, items[position], values).first(where: { $0.key == fieldKey }) else {
            return nil
        }
        return ItemField(group: group, index: position, field: field)
    }

    func affectsStructure(_ key: String, _ cleared: Set<String>) -> Bool {
        index.routeFields.contains(key) || index.fieldDependents.has(key) || index.stepDependents.has(key) || !cleared.isEmpty
    }

    private func reconcileItems(_ values: inout JSONObject, _ errors: inout [String: String], _ cleared: inout Set<String>) {
        for group in groups where activeField(group.key, values) === group {
            let source = itemsOf(values[group.key])
            let items = source.enumerated().map { position, item -> JSONValue in
                guard var entry = item.objectValue else { return item }
                for _ in 0...group.items.count {
                    let shown = itemFields(group, .object(entry), values)
                    let hidden = group.items.filter { field in !shown.contains { $0 === field } && entry.has(field.key) }
                    if hidden.isEmpty { break }
                    for field in hidden {
                        entry.removeValue(forKey: field.key)
                        cleared.insert(itemPath(group.key, position, field.key))
                    }
                }
                return .object(entry)
            }
            if items != source { values[group.key] = .array(items) }
            for key in errors.keys {
                guard let (position, field) = splitPath(group.key, key) else { continue }
                if position < items.count, itemFields(group, items[position], values).contains(where: { $0.key == field }) { continue }
                errors.removeValue(forKey: key)
                cleared.insert(key)
            }
        }
    }

    @discardableResult
    func reconcileHidden(_ values: inout JSONObject, _ errors: inout [String: String], initial: Bool = false) -> Set<String> {
        if initial { starts.resetStarts(values) }
        let order = OrderedKeys(index.fieldDependents.keys + index.stepDependents.keys).keys
        var queue = order
        var queued = Set(queue)
        var cleared = Set<String>()
        let groupKeys = Set(groups.map(\.key))
        func held(_ key: String) -> Bool { values[key] != nil || errors[key] != nil }
        func mark(_ key: String) {
            cleared.insert(key)
            for next in index.routeFields.contains(key) ? order + [key] : [key] where !queued.contains(next) {
                queued.insert(next)
                queue.append(next)
            }
        }
        func clear(_ key: String) {
            starts.remember(key, values[key])
            values.removeValue(forKey: key)
            errors.removeValue(forKey: key)
            if groupKeys.contains(key) {
                for errorKey in errors.keys where owner(errorKey) == key { errors.removeValue(forKey: errorKey) }
            }
            mark(key)
        }
        func update(_ field: FormField, _ shown: Bool) {
            let key = field.key
            let shared = (index.fieldsByKey[key]?.count ?? 0) > 1
            let active = shared ? activeField(key, values) : nil
            if let active, active !== field { return }
            guard shown else {
                if held(key) { clear(key) }
                return
            }
            let eligible = shared ? active != nil : onPath(field, values) && visible(field, values)
            guard !held(key), eligible, let value = starts.startValue(field) else { return }
            values[key] = value
            mark(key)
        }
        var position = 0
        while position < queue.count {
            let key = queue[position]
            queued.remove(key)
            for field in index.fieldDependents[key] ?? [] where onPath(field, values) {
                update(field, visible(field, values))
            }
            for step in index.stepDependents[key] ?? [] {
                for field in valueFields(step.fields) { update(field, isVisible(step, scope(values))) }
            }
            position += 1
        }
        if !groups.isEmpty { reconcileItems(&values, &errors, &cleared) }
        return cleared
    }
}

struct OrderedKeys {
    private(set) var keys: [String] = []

    init(_ items: [String]) {
        var seen = Set<String>()
        for item in items where seen.insert(item).inserted { keys.append(item) }
    }
}

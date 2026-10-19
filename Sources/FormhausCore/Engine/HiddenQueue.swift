private struct HiddenPass {
    let visibility: VisibilityState
    var values: Values
    var errors: FieldErrors
    let fields: Set<Int>?
    var queue: [String] = []
    var queued = KeySet()
    var cleared = KeySet()

    var index: DefinitionIndex { visibility.index }

    func held(_ key: String) -> Bool { values[key] != nil || errors[key] != nil }

    mutating func mark(_ key: String) {
        cleared.insert(key)
        for next in index.routeFields.contains(key) ? visibility.order + [key] : [key] where !queued.contains(next) {
            queued.insert(next)
            queue.append(next)
        }
    }

    mutating func clear(_ key: String) {
        visibility.starts.remember(key, values.slot(key))
        values.remove(key)
        errors.removeValue(forKey: key)
        if visibility.groups.contains(where: { sameText($0.key, key) }) {
            for errorKey in errors.keys where sameText(visibility.owner(errorKey), key) { errors.removeValue(forKey: errorKey) }
        }
        mark(key)
    }

    mutating func update(_ field: FormField, _ shown: Bool, dry: Bool) -> Bool {
        let key = field.key
        if dry {
            visibility.waiting.remove(key)
            if values[key] == nil && errors[key] != nil { visibility.waiting.insert(key) }
        }
        let shared = index.isShared(key)
        let active = shared ? visibility.activeField(key, values.json) : nil
        if let active, active.ordinal != field.ordinal { return false }
        guard shown else {
            let hidden = held(key)
            if hidden && !dry { clear(key) }
            return hidden
        }
        let eligible = shared ? active != nil : visibility.onPath(field, values.json) && visibility.visible(field, values.json)
        if held(key) || !eligible { return false }
        let start = visibility.starts.startValue(field)
        guard start.value != nil else { return false }
        if dry { return true }
        values.set(key, start)
        visibility.starts.seedItems(values.slot(key))
        mark(key)
        return true
    }

    func included(_ field: FormField) -> Bool {
        fields?.contains(field.ordinal) ?? true
    }

    mutating func visit(_ key: String, dry: Bool) -> Bool {
        var acted = false
        for field in index.fieldDependents[key] ?? [] where included(field) && visibility.onPath(field, values.json) {
            let shown = visibility.visible(field, values.json)
            acted = update(field, shown, dry: dry) || acted
        }
        for step in index.stepDependents[key] ?? [] {
            for field in valueFields(step.fields) where included(field) {
                let shown = isVisible(step, visibility.scope(values.json), limits: visibility.limits(values.json))
                acted = update(field, shown, dry: dry) || acted
            }
        }
        return acted
    }
}

extension VisibilityState {
    private func downstream(_ key: String) -> Set<Int>? {
        var fields = Set<Int>()
        var keys = [key]
        var seen = KeySet(keys)
        var position = 0
        while position < keys.count {
            let next = keys[position]
            position += 1
            if index.routeFields.contains(next) || index.stepDependents.has(next) { return nil }
            for field in index.fieldsByKey[next] ?? [] { fields.insert(field.ordinal) }
            for field in index.fieldDependents[next] ?? [] where seen.insert(field.key) { keys.append(field.key) }
        }
        return fields
    }

    @discardableResult
    func reconcileHidden(_ values: inout Values, _ errors: inout FieldErrors, initial: Bool = false, written: String? = nil) -> KeySet {
        if initial { starts.resetStarts(values, groups: groups) }
        let incremental = !initial && written != nil && settled && waiting.allSatisfy { values[$0] != nil || errors[$0] != nil }
        let fields = incremental ? written.flatMap(downstream) : nil
        var keys = order
        if let fields {
            let position = StringMap(order.enumerated().map { ($1, $0) })
            let fieldList = allFields.filter { fields.contains($0.ordinal) }
            keys = OrderedKeys(fieldList.flatMap(index.conditionSources)).keys.sorted {
                (position[$0] ?? Int.max) < (position[$1] ?? Int.max)
            }
        }
        var pass = HiddenPass(visibility: self, values: values, errors: errors, fields: fields)
        pass.queue = keys
        pass.queued = KeySet(keys)
        var cursor = 0
        while cursor < pass.queue.count {
            let key = pass.queue[cursor]
            pass.queued.remove(key)
            _ = pass.visit(key, dry: false)
            cursor += 1
        }
        if !groups.isEmpty { reconcileItems(&pass.values, &pass.errors, &pass.cleared) }
        if fields == nil { waiting = KeySet() }
        settled = true
        for key in keys where pass.visit(key, dry: true) {
            settled = false
            break
        }
        values = pass.values
        errors = pass.errors
        return pass.cleared
    }
}

extension StringMap where Value == Int {
    init(_ pairs: [(String, Int)]) {
        self.init()
        for (key, value) in pairs where !has(key) { self[key] = value }
    }
}

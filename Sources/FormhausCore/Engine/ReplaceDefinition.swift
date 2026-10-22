private func kept(_ fields: [FormField]?, _ field: FormField?) -> Bool {
    guard let field else { return false }
    return fields?.contains { sameText($0.key, field.key) && sameText($0.type, field.type) } == true
}

private func sameItems(_ previous: JSONValue?, _ next: JSONValue?) -> Bool {
    guard let old = previous?.arrayValue, let new = next?.arrayValue else { return false }
    return old == new
}

extension EngineCore {
    private func carriedValues(_ values: Values, _ fields: [FormField], _ previous: VisibilityState) -> Values {
        var result = Values()
        for field in fields where kept(previous.allFields, field) && values.has(field.key) {
            let slot = values.slot(field.key)
            guard field.isGroup, let items = slot.value?.arrayValue else {
                result.set(field.key, slot)
                continue
            }
            let old = previous.groups.first { sameText($0.key, field.key) }?.items
            let filtered = items.map { item -> JSONValue in
                guard let entry = item.objectValue else { return item }
                var next = JSONObject()
                for (key, value) in entry where kept(old, field.items.first { sameText($0.key, key) }) { next[key] = value }
                return .object(next)
            }
            result.set(field.key, ValueSlot(.array(filtered), ref: Ref(token: freshToken(), items: values.itemIds(field.key))))
        }
        return result
    }

    private func keepsError(_ key: String, _ previous: VisibilityState) -> Bool {
        let parsed = visibility.parse(key)
        let field = visibility.activeField(parsed?.group ?? key, values.json)
        guard kept(previous.allFields, field) else { return false }
        guard let parsed else { return true }
        let old = previous.groups.first { sameText($0.key, parsed.group) }?.items
        return kept(old, field?.items.first { sameText($0.key, parsed.field) })
    }

    func replaceDefinition(_ next: FormDefinition) {
        let previous = visibility
        let previousValues = keptValues()
        let steps = visibleSteps
        let stepIndex = currentStepIndex
        restarts += 1
        baselineFields()
        load(next, carriedValues(previousValues, next.allFields, previous))
        validationEpoch += 1
        operationEpoch += 1
        stepValidating = false
        if sending != latestOperation { submitting = false }
        for key in errors.keys where !keepsError(key, previous) { errors.removeValue(forKey: key) }
        for key in serverErrors.keys where errors[key] == nil { serverErrors.removeValue(forKey: key) }
        currentStepIndex = reconcileStepIndex(steps, visibleSteps, stepIndex)
        skipped = skipped.compactMap { entry in
            next.steps?.first { sameText($0.id, entry.id) }.map { (entry.id, valueFields($0.fields).map(\.key)) }
        }
        let current = keptValues()
        let valuesChanged = previousValues.changedKeys(current).contains { !sameItems(previousValues[$0], current[$0]) }
        notify(structureChanged: true, valuesChanged: valuesChanged)
        if !valuesChanged { trackChanges(fields: true) }
    }
}

extension EngineCore {
    func writeValue(_ key: String, _ slot: ValueSlot, own: Bool = true, after: () -> Void = {}) {
        baselineFields()
        let previousSteps = isMultiStep ? visibleSteps : nil
        let valueChanged = !values.slot(key).isSame(slot)
        values.set(key, slot)
        visibility.starts.remember(key, slot, written: true)
        if own { clearError(key, server: valueChanged) }
        if valueChanged { skipped.removeAll { $0.keys.containsText(key) } }
        let cleared = reconcileHidden(written: key)
        dropServerErrors(cleared)
        _ = clearResolvedMatchErrors(key)
        after()
        let valuesChanged = valueChanged || !cleared.isEmpty
        let structureChanged = valuesChanged && visibility.affectsStructure(key, cleared)
        if let previousSteps, structureChanged {
            visibility.markChanged(true, true)
            currentStepIndex = reconcileStepIndex(previousSteps, visibleSteps, currentStepIndex)
            pruneOffPathErrors()
        }
        notify(structureChanged: structureChanged, valuesChanged: valuesChanged)
    }

    func setValue(_ key: String, _ value: JSONValue?) {
        if let (group, index, field) = visibility.parse(key) {
            setItemValue(group, index, field, value)
        } else {
            writeValue(key, .fresh(exclusiveWrite(visibility.fieldOf(key, values.json), values[key], value)))
        }
    }

    func loadSubmitted(_ submitted: JSONObject) {
        replaceValues(Values(fresh: submitted))
        reconcileHidden(initial: true)
        visibility.markChanged(true, true)
        visibility.starts.loadPayload()
        visibility.unsettle()
    }
}

extension EngineCore {
    private func activeGroup(_ key: String) -> FormField? {
        guard let field = visibility.activeField(key, values.json), field.isGroup else { return nil }
        return field
    }

    func itemLimits(_ group: FormField) -> (min: Double, max: Double) {
        let rules = group.validation
        let required = rules?.required?.isTruthy == true
        return (rules?.minLength ?? (required ? 1 : 0), rules?.maxLength ?? 100)
    }

    func items(_ key: String) -> [GroupItem] {
        guard let group = activeGroup(key) else { return [] }
        return itemsOf(values[key]).enumerated().map { index, item in
            let id = item.objectValue != nil ? values.itemId(key, index).map { "i\($0)" } ?? "\(index)" : "\(index)"
            return GroupItem(id: id, fields: visibility.itemFields(group, item, values.json))
        }
    }

    func addItem(_ key: String) -> Bool {
        let items = itemsOf(values[key])
        guard let group = activeGroup(key), Double(items.count) < itemLimits(group).max else { return false }
        let id = freshToken()
        let item = JSONValue.object(createItem(group.items))
        visibility.starts.seedItems(ValueSlot(.array([item]), ref: Ref(token: 0, items: [id])))
        let ids = values.itemIds(key)
        writeValue(key, ValueSlot(.array(items + [item]), ref: Ref(token: freshToken(), items: ids + [id])))
        return true
    }

    private func shift<V>(_ map: inout StringMap<V>, _ key: String, _ removed: Int) {
        var moved = StringMap<V>()
        for errorKey in map.keys {
            guard let (index, field) = splitPath(key, errorKey), index >= removed else { continue }
            if index > removed { moved[itemPath(key, index - 1, field)] = map[errorKey] }
            map.removeValue(forKey: errorKey)
        }
        map.merge(moved)
    }

    func removeItem(_ key: String, _ index: Int) -> Bool {
        let items = itemsOf(values[key])
        guard let group = activeGroup(key), items.indices.contains(index), Double(items.count) > itemLimits(group).min else { return false }
        var ids = values.itemIds(key)
        visibility.starts.dropItem(values.itemId(key, index))
        shift(&errors, key, index)
        shift(&serverErrors, key, index)
        shift(&fieldLoading, key, index)
        var next = items
        next.remove(at: index)
        if ids.indices.contains(index) { ids.remove(at: index) }
        writeValue(key, ValueSlot(.array(next), ref: Ref(token: freshToken(), items: ids)))
        return true
    }

    func setItemValue(_ key: String, _ index: Int, _ fieldKey: String, _ input: JSONValue?) {
        let items = itemsOf(values[key])
        guard let group = activeGroup(key), let field = group.items.first(where: { sameText($0.key, fieldKey) }),
            items.indices.contains(index)
        else { return }
        let current = items[index]
        let item = current.objectValue ?? JSONObject()
        let value = exclusiveWrite(field, item[fieldKey], input)
        let path = itemPath(key, index, fieldKey)
        let changed = !samePrimitive(item[fieldKey], value)
        var slot = values.slot(key)
        if let value, current.objectValue != nil { visibility.starts.rememberItem(values.itemId(key, index), fieldKey, value) }
        if changed {
            var updated = item
            updated[fieldKey] = value
            var next = items
            next[index] = .object(updated)
            var ids = values.itemIds(key)
            if current.objectValue == nil, ids.indices.contains(index) { ids[index] = freshToken() }
            slot = ValueSlot(.array(next), ref: Ref(token: freshToken(), items: ids))
        }
        clearError(path, server: changed)
        writeValue(key, slot, own: false) {
            _ = clearResolvedMatchErrors(fieldKey, item: ItemField(group: group, index: index, field: field))
        }
    }
}

func errorKeys(_ nodes: [FormNode], _ errors: FieldErrors, _ values: JSONObject) -> [String] {
    if errors.isEmpty { return [] }
    return valueFields(nodes).flatMap { field -> [String] in
        let own = field.type != "hidden" && errors[field.key] != nil ? [field.key] : []
        guard field.isGroup else { return own }
        let paths = itemsOf(values[field.key]).indices.flatMap { index in field.items.map { itemPath(field.key, index, $0.key) } }
        return own + paths.filter { errors[$0] != nil }
    }
}

extension EngineCore {
    private func unsettleOnWrite<T>(_ run: () -> T) -> T {
        let before = version
        let result = run()
        if before != version { visibility.unsettle() }
        return result
    }

    func fieldsErrors(_ nodes: [FormNode], _ submitValues: JSONObject? = nil) -> FieldErrors {
        let values = submitValues ?? getSubmitValues()
        let scope = visibility.conditionValues(self.values.json)
        return CallBudget.run {
            unsettleOnWrite {
                validateShown(
                    nodes, values, scope,
                    ShownChecks(validators: validators, messages: .function(messages), limits: visibility.limits(self.values.json)))
            }
        }
    }

    func fieldError(_ field: FormField, _ value: JSONValue?, _ allValues: JSONObject? = nil) -> String? {
        let all = allValues ?? getSubmitValues()
        return CallBudget.run {
            unsettleOnWrite { validateFieldValue(field, value, all, validators: validators, messages: .function(messages)) }
        }
    }

    func itemError(_ item: ItemField) -> String? {
        let values = getSubmitValues()
        let items = itemsOf(values[item.group.key])
        let scope = itemScope(item.group, items.indices.contains(item.index) ? items[item.index] : .null, values)
        return fieldError(item.field, scope[item.field.key], scope)
    }

    func applyValidationErrors(_ found: FieldErrors, server: Bool = false, formErrors: [String] = []) {
        var bound = FieldErrors()
        var general = formErrors
        for (key, message) in found {
            if visibility.activeField(key, values.json) != nil || visibility.activeItem(key, values.json) != nil {
                bound[key] = message
            } else {
                general.append(message)
            }
        }
        if server {
            replaceServerErrors(bound)
            serverFormErrors = general
        }
        replaceErrors(serverErrors.merging(bound))
        topLevelErrors = server ? general : serverFormErrors + general
        let structureChanged = server && moveToFirstError(bound)
        notify(structureChanged: structureChanged)
    }

    func moveToFirstError(_ found: FieldErrors) -> Bool {
        guard let target = visibleSteps.firstIndex(where: { !errorKeys($0.fields, found, values.json).isEmpty }),
            target != currentStepIndex
        else { return false }
        currentStepIndex = target
        return true
    }

    func clearError(_ key: String, server: Bool = false) {
        if server { serverErrors.removeValue(forKey: key) }
        errors[key] = serverErrors[key]
    }

    func dropServerErrors(_ keys: some Sequence<String>) {
        let dropped = KeySet(keys)
        for key in serverErrors.keys where dropped.contains(key) || dropped.contains(visibility.owner(key)) {
            serverErrors.removeValue(forKey: key)
        }
    }

    func clearResolvedMatchErrors(_ key: String, item: ItemField? = nil) -> [String] {
        var cleared: [String] = []
        let fields: [(String, FormField)] =
            item.map { item in item.group.items.map { (itemPath(item.group.key, item.index, $0.key), $0) } }
            ?? visibility.allFields.map { ($0.key, $0) }
        for (path, field) in fields {
            guard let match = field.validation?.matchField, sameText(match, key), errors[path] != nil else { continue }
            let error =
                item.map { itemError(ItemField(group: $0.group, index: $0.index, field: field)) } ?? fieldError(field, values[field.key])
            if error != nil { continue }
            clearError(path)
            cleared.append(path)
        }
        guard item == nil else { return cleared }
        for group in visibility.groups {
            guard visibility.activeField(group.key, values.json)?.ordinal == group.ordinal,
                group.items.contains(where: { $0.validation?.matchField.map { sameText($0, key) } == true }), let first = group.items.first
            else { continue }
            for index in itemsOf(values[group.key]).indices {
                cleared += clearResolvedMatchErrors(key, item: ItemField(group: group, index: index, field: first))
            }
        }
        return cleared
    }

    @discardableResult
    func pruneOffPathErrors() -> [String] {
        let pathFields = KeySet(visibleSteps.flatMap { valueFields($0.fields).map(\.key) })
        let pruned = errors.keys.filter { !pathFields.contains(visibility.owner($0)) }
        for key in pruned { errors.removeValue(forKey: key) }
        dropServerErrors(pruned)
        return pruned
    }

    func getSubmitValues() -> JSONObject {
        var result = visibility.conditionValues(values.json)
        for key in skipped.flatMap(\.keys) { result.removeValue(forKey: key) }
        return result
    }

    @discardableResult
    func validate(navigate: Bool = false) -> FieldErrors {
        let found = CallBudget.run(collectErrors)
        replaceErrors(serverErrors.merging(found))
        let structureChanged = navigate && moveToFirstError(found)
        notify(structureChanged: structureChanged)
        return found
    }

    private func collectErrors() -> FieldErrors {
        var found = FieldErrors()
        if isMultiStep {
            var seen = -1
            var submitValues = JSONObject()
            for step in visibleSteps where !isStepSkipped(step.id) {
                if seen != version {
                    seen = version
                    submitValues = getSubmitValues()
                }
                found.merge(fieldsErrors(step.fields, submitValues))
            }
        } else {
            found = fieldsErrors(definition.fields ?? [])
        }
        return found
    }

    func validateOne(_ key: String) -> String? {
        let field = visibility.activeField(key, values.json)
        let item = field == nil ? visibility.activeItem(key, values.json) : nil
        guard field != nil || item != nil else { return nil }
        let error = item.map(itemError) ?? field.flatMap { fieldError($0, values[key]) }
        if let error {
            errors[key] = error
        } else {
            clearError(key, server: true)
        }
        notify()
        return error
    }
}

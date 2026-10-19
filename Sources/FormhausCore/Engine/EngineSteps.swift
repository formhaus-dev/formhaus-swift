extension FormEngine {
    func includeCurrentStep() {
        guard let step = currentStep else { return }
        skipped.removeAll { $0.id == step.id }
    }

    func dropServerErrors(_ keys: some Sequence<String>) {
        let dropped = Set(keys)
        for key in serverErrors.keys where dropped.contains(key) || dropped.contains(visibility.owner(key)) {
            serverErrors.removeValue(forKey: key)
        }
    }

    @discardableResult
    func pruneOffPathErrors() -> [String] {
        let pathFields = Set(visibleSteps.flatMap { valueFields($0.fields).map(\.key) })
        let pruned = errors.keys.filter { !pathFields.contains(visibility.owner($0)) }
        for key in pruned { errors.removeValue(forKey: key) }
        dropServerErrors(pruned)
        return pruned
    }

    func reconcile() -> Set<String> {
        var values = self.values
        var errors = self.errors
        let cleared = visibility.reconcileHidden(&values, &errors)
        self.values = values
        self.errors = errors
        return cleared
    }

    func loadSubmitted(_ submitted: JSONObject) {
        values = submitted
        var errors = self.errors
        visibility.reconcileHidden(&values, &errors, initial: true)
        self.errors = errors
        visibility.starts.loadPayload()
    }

    func skipStep(at index: Int) {
        currentStepIndex = index
        guard let step = currentStep else { return }
        let fields = valueFields(step.fields)
        let fieldKeys = fields.map(\.key)
        var reset = values
        for key in fieldKeys { reset.removeValue(forKey: key) }
        reset.merge(createValues(fields))
        values = reset
        visibility.starts.reseed(fieldKeys, values)
        for key in errors.keys where fieldKeys.contains(visibility.owner(key)) { errors.removeValue(forKey: key) }
        dropServerErrors(fieldKeys)
        if let position = skipped.firstIndex(where: { $0.id == step.id }) {
            skipped[position].keys = fieldKeys
        } else {
            skipped.append((step.id, fieldKeys))
        }
        dropServerErrors(reconcile())
        pruneOffPathErrors()
    }

    func writeValue(_ key: String, _ value: JSONValue?) {
        let previousSteps = isMultiStep ? visibleSteps : nil
        let changed = values[key] != value
        values[key] = value
        visibility.starts.remember(key, value)
        if changed { skipped.removeAll { $0.keys.contains(key) } }
        let cleared = reconcile()
        dropServerErrors(cleared)
        guard let previousSteps, (changed || !cleared.isEmpty) && visibility.affectsStructure(key, cleared) else { return }
        currentStepIndex = reconcileStepIndex(previousSteps, visibleSteps, currentStepIndex)
        pruneOffPathErrors()
    }
}

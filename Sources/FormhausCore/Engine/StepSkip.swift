extension EngineCore {
    private func resetStepValues() -> Values {
        let fields = valueFields(currentStep?.fields ?? [])
        var next = values
        for field in fields { next.remove(field.key) }
        next.merge(createValues(fields))
        return next
    }

    func skipTarget() -> FormStep? {
        let steps = activeSteps(definition, resetStepValues().json)
        return steps.indices.contains(currentStepIndex + 1) ? steps[currentStepIndex + 1] : nil
    }

    func skipCurrentStep() -> StartValues.Restore? {
        currentStep.map(skip)
    }

    func skip(_ step: FormStep) -> StartValues.Restore {
        let fieldKeys = valueFields(step.fields).map(\.key)
        baselineFields()
        replaceValues(resetStepValues())
        let restore = visibility.starts.reseed(fieldKeys, values)
        visibility.unsettle()
        for key in errors.keys where fieldKeys.containsText(visibility.owner(key)) { errors.removeValue(forKey: key) }
        dropServerErrors(fieldKeys)
        markSkipped(step.id, fieldKeys)
        dropServerErrors(reconcileHidden())
        visibility.markChanged(true, true)
        pruneOffPathErrors()
        notify(structureChanged: true, valuesChanged: true)
        return restore
    }

    func includeCurrentStep() {
        if let step = currentStep { unmarkSkipped(step.id) }
    }

    @discardableResult
    func skipStep(at index: Int) -> StartValues.Restore? {
        currentStepIndex = index
        notify(structureChanged: true)
        return skipCurrentStep()
    }

    func reset(_ initialValues: JSONObject?) {
        let previousValues = values
        baselineFields()
        validationEpoch += 1
        operationEpoch += 1
        let visibility = visibility
        replaceValues(createValues(visibility.allFields, initialValues.map { Values(fresh: $0) }) { visibility.activeField($0, $1) })
        replaceErrors(FieldErrors())
        replaceServerErrors(FieldErrors())
        topLevelErrors = []
        serverFormErrors = []
        currentStepIndex = 0
        fieldLoading = [:]
        stepValidating = false
        submitting = false
        skipped = []
        reconcileHidden(initial: true)
        if started {
            emit(.formReset)
            viewedStep = nil
        }
        let changed = previousValues.changedKeys(values)
        notify(structureChanged: true, valuesChanged: !changed.isEmpty)
    }
}

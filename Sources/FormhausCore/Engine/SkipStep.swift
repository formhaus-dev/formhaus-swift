private struct SkippedStep {
    let step: FormStep
    let values: Values
    let errors: FieldErrors
    let serverErrors: FieldErrors
    let restore: StartValues.Restore
}

extension FormEngine {
    @discardableResult
    public func skip(_ handler: SubmitHandler? = nil) async throws -> Bool {
        try await reportErrors { try await skipStep(handler) }
    }

    private func skipStep(_ submit: SubmitHandler?) async throws -> Bool {
        let core = core
        guard core.isMultiStep, !core.stepValidating, !core.submitting, core.currentStep?.canSkip == true else { return false }
        if core.skipTarget() != nil { return try await changeStep(forward: true, reason: .skip) }
        guard let submit, let step = core.currentStep else { return false }
        let values = core.values
        let errors = core.errors
        let serverErrors = core.serverErrors
        let outcome = Box<Bool?>(nil)
        let skipped = SkippedStep(step: step, values: values, errors: errors, serverErrors: serverErrors, restore: core.skip(step))
        let skippedGeneration = core.valuesGeneration
        let skippedValues = core.values
        let watch = core.visibility.starts.watchWrites()
        let operationBox = Box(core.latestOperation)
        defer {
            let writes = core.visibility.starts.endWatch(watch)
            if outcome.value != false && operationBox.value == core.latestOperation && core.valuesGeneration == skippedGeneration {
                var kept = skippedValues.changedKeys(core.values)
                kept.formUnion(writes)
                restoreSkipped(skipped, outcome.value, kept, writes)
            }
        }
        return try await suspended {
            try await submitForm(
                { submitted, skipped in
                    let result = try await suspended { try await submit(submitted, skipped) }
                    let rejected = result?.isRejection == true
                    if !rejected || operationBox.value == core.operationEpoch { outcome.value = rejected }
                    return result
                }, keepSkipped: true, operationBox: operationBox)
        }
    }

    private func restoreSkipped(_ saved: SkippedStep, _ outcome: Bool?, _ kept: KeySet, _ writes: KeySet) {
        let core = core
        let visibility = core.visibility
        var errors = saved.errors
        var serverErrors = saved.serverErrors
        let steps = core.visibleSteps
        let current = core.values
        core.baselineFields()
        var restored = saved.values
        for key in kept {
            restored.remove(key)
            for errorKey in errors.keys where sameText(visibility.owner(errorKey), key) { errors.removeValue(forKey: errorKey) }
            for errorKey in serverErrors.keys where sameText(visibility.owner(errorKey), key) { serverErrors.removeValue(forKey: errorKey) }
            if current.has(key) { restored.set(key, current.slot(key)) }
        }
        core.replaceValues(restored)
        let reverted = current.changedKeys(core.values)
        if outcome == nil {
            core.replaceServerErrors(serverErrors)
        } else {
            core.dropServerErrors(reverted)
        }
        var fresh = core.errors
        for key in fresh.keys where reverted.contains(visibility.owner(key)) { fresh.removeValue(forKey: key) }
        core.replaceErrors((outcome == true ? FieldErrors() : errors).merging(fresh))
        core.unmarkSkipped(saved.step.id)
        visibility.starts.restore(saved.restore, kept: writes)
        visibility.unsettle()
        core.dropServerErrors(core.reconcileHidden())
        visibility.markChanged(true, true)
        core.currentStepIndex = reconcileStepIndex(steps, core.visibleSteps, core.currentStepIndex)
        core.pruneOffPathErrors()
        core.notify(structureChanged: true, valuesChanged: true)
    }
}

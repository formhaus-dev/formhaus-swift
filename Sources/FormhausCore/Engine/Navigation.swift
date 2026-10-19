extension EngineCore {
    func activePathKey() -> [String] {
        visibleSteps.map(\.id)
    }

    func watchCheckedInputs(_ checked: JSONObject) -> () -> Bool {
        let path = activePathKey()
        let seen = checked.keys.map { ($0, values.slot($0)) }
        return { [unowned self] in
            let current = activePathKey()
            return current.count != path.count || !zip(current, path).allSatisfy(sameText)
                || seen.contains { !values.slot($0.0).isSame($0.1) }
        }
    }

    func hasStepErrors() -> Bool {
        guard let step = currentStep else { return true }
        let found = fieldsErrors(step.fields)
        if found.isEmpty { return false }
        replaceErrors(errors.merging(found))
        notify()
        return true
    }
}

@MainActor
func suspended<T>(_ body: () async throws -> T) async throws -> T {
    do {
        let result = try await body()
        await Task.yield()
        return result
    } catch {
        await Task.yield()
        throw error
    }
}

extension FormEngine {
    func reportErrors(_ action: () async throws -> Bool) async throws -> Bool {
        let generation = core.errorsGeneration
        let done = try await suspended(action)
        if !done && core.errorsGeneration != generation {
            for (fieldKey, error) in core.errors { core.emit(.fieldError(fieldKey: fieldKey, error: error)) }
        }
        return done
    }

    func afterCommit(_ phase: FormLifecycleError.Phase, _ callback: () async throws -> Void) async throws {
        do {
            try await suspended(callback)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw FormLifecycleError(phase: phase, cause: error)
        }
    }

    @discardableResult
    public func next() async throws -> Bool {
        try await advance(.next)
    }

    @discardableResult
    public func back() async throws -> Bool {
        try await changeStep(forward: false, reason: .back)
    }

    func advance(_ reason: StepChangeReason) async throws -> Bool {
        try await reportErrors { try await changeStep(forward: true, reason: reason) }
    }

    func changeStep(forward: Bool, reason: StepChangeReason) async throws -> Bool {
        let core = core
        let skipping = reason == .skip
        guard core.isMultiStep, !core.stepValidating, !core.submitting else { return false }
        if !skipping && (forward ? core.isLastStep : core.isFirstStep) { return false }
        guard let step = core.currentStep else { return false }
        let validating = forward && !skipping
        if validating { core.includeCurrentStep() }
        if validating && core.hasStepErrors() { return false }
        let lifecycle = options
        var committed = false
        let toIndex = core.currentStepIndex + (forward ? 1 : -1)
        let steps = core.visibleSteps
        let target = skipping ? core.skipTarget() : steps.indices.contains(toIndex) ? steps[toIndex] : nil
        guard let target else { return false }
        let context = StepChangeContext(fromStepId: step.id, toStepId: target.id, reason: reason, values: core.getSubmitValues())
        let epoch = core.validationEpoch
        core.operationEpoch += 1
        let operation = core.operationEpoch
        core.latestOperation = operation
        let inputsChanged = core.watchCheckedInputs(context.values)
        let stale = {
            epoch != core.validationEpoch || operation != core.operationEpoch
                || core.currentStep.map { sameText($0.id, step.id) } != true || inputsChanged()
        }
        core.stepValidating = true
        core.notify()
        defer {
            if operation == core.operationEpoch {
                core.stepValidating = false
                core.notify()
            }
        }
        do {
            if stale() { return false }
            if validating, let validate = lifecycle.onStepValidate {
                let result = try await suspended { try await validate(step.id, context.values) }
                if stale() { return false }
                if let result, !result.isEmpty {
                    core.applyValidationErrors(result)
                    return false
                }
            }
            if let before = lifecycle.onBeforeStepChange {
                let allowed = try await suspended { try await before(context) }
                if stale() || allowed == false { return false }
            }
            if stale() { return false }
            if validating && core.hasStepErrors() { return false }
            committed = true
            if forward { core.emit(skipping ? .stepSkipped(stepId: step.id) : .stepCompleted(stepId: step.id)) }
            if skipping { _ = core.skipCurrentStep() }
            moveTo(toIndex)
            try await suspended { try await afterCommit(.afterStepChange) { try await lifecycle.onAfterStepChange?(context) } }
            return true
        } catch is CancellationError {
            return committed
        } catch {
            if !committed && stale() { return false }
            throw error
        }
    }
}

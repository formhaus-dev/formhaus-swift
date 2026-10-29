struct StepMove {
    let step: FormStep
    let target: FormStep
    let index: Int
    let forward: Bool
    let skipping: Bool
    let ruleErrors: FieldErrors

    var validating: Bool { forward && !skipping }
    var invalid: Bool { !ruleErrors.isEmpty }
}

extension EngineCore {
    func plannedMove(forward: Bool, reason: StepChangeReason, withRules: Bool) -> StepMove? {
        let skipping = reason == .skip
        guard isMultiStep, !stepValidating, !submitting else { return nil }
        if !skipping && (forward ? isLastStep : isFirstStep) { return nil }
        guard let step = currentStep else { return nil }
        clearFormErrors()
        let validating = forward && !skipping
        if validating { includeCurrentStep() }
        let ruleErrors = validating ? stepErrors() : FieldErrors()
        guard let ruleErrors, ruleErrors.isEmpty || withRules else { return nil }
        let index = currentStepIndex + (forward ? 1 : -1)
        let steps = visibleSteps
        let target = skipping ? skipTarget() : steps.indices.contains(index) ? steps[index] : nil
        guard let target else { return nil }
        return StepMove(step: step, target: target, index: index, forward: forward, skipping: skipping, ruleErrors: ruleErrors)
    }

    func beginOperation() -> Int {
        operationEpoch += 1
        latestOperation = operationEpoch
        return operationEpoch
    }

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
                || getSubmitValues().keys.contains { !checked.has($0) && visibility.activeField($0, values.json)?.type != "hidden" }
        }
    }

    private func stepErrors() -> FieldErrors? {
        guard let step = currentStep else { return nil }
        let found = fieldsErrors(step.fields)
        if found.isEmpty { return found }
        replaceErrors(errors.merging(found))
        notify()
        return found
    }

    func hasStepErrors() -> Bool {
        stepErrors()?.isEmpty != true
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
        let done = try await CallBudget.run { try await suspended(action) }
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
        guard let move = core.plannedMove(forward: forward, reason: reason, withRules: validatesWithRules) else { return false }
        let step = move.step
        var committed = false
        let context = StepChangeContext(
            fromStepId: step.id, toStepId: move.target.id, reason: reason, values: core.getSubmitValues(payload: true))
        let epoch = core.validationEpoch
        let operation = core.beginOperation()
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
            guard try await approve(move, context, stale) else { return false }
            committed = true
            commit(move)
            try await suspended { try await afterCommit(.afterStepChange) { try await options.onAfterStepChange?(context) } }
            return true
        } catch is CancellationError {
            return committed
        } catch {
            if !committed && stale() { return false }
            throw error
        }
    }

    private func approve(_ move: StepMove, _ context: StepChangeContext, _ stale: () -> Bool) async throws -> Bool {
        if stale() { return false }
        guard try await passesStepHooks(move, context, stale) else { return false }
        if let before = options.onBeforeStepChange {
            let allowed = try await suspended { try await before(context) }
            if stale() || allowed == false { return false }
        }
        if stale() { return false }
        return !(move.validating && core.hasStepErrors())
    }

    private func passesStepHooks(_ move: StepMove, _ context: StepChangeContext, _ stale: () -> Bool) async throws -> Bool {
        guard move.validating else { return true }
        if !move.invalid, let validate = options.onStepValidate {
            let result = try await suspended { try await validate(move.step.id, context.values) }
            if stale() { return false }
            if let result, !result.isEmpty {
                core.applyValidationErrors(result)
                return false
            }
        }
        if let validate = options.onValidate,
            try await !passesValidate(validate, context.values, stale, submit: false, ruleErrors: move.ruleErrors)
        {
            return false
        }
        return !move.invalid
    }

    private func commit(_ move: StepMove) {
        if move.forward { core.emit(move.skipping ? .stepSkipped(stepId: move.step.id) : .stepCompleted(stepId: move.step.id)) }
        if move.skipping { _ = core.skipCurrentStep() }
        if move.validating { core.clearPassedErrors(move.step.fields) }
        moveTo(move.index)
    }
}

@MainActor
final class Box<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

extension FormEngine {
    @discardableResult
    public func submit(_ handler: @escaping SubmitHandler) async throws -> Bool {
        try await reportErrors { try await submitForm(handler) }
    }

    private func applyRejection(_ errors: FieldErrors, _ formErrors: [String], _ sent: Values) {
        var accepted = FieldErrors()
        for (key, message) in errors {
            let owner = core.visibility.owner(key)
            if core.values.slot(owner).isSame(sent.slot(owner)) { accepted[key] = message }
        }
        core.applyValidationErrors(accepted, server: true, formErrors: formErrors)
    }

    func submitForm(_ submit: SubmitHandler, keepSkipped: Bool = false, operationBox: Box<Int>? = nil) async throws -> Bool {
        let core = core
        guard !core.submitting, !core.stepValidating else { return false }
        if !keepSkipped { core.includeCurrentStep() }
        let lifecycle = options
        var dispatched = false
        let epoch = core.validationEpoch
        core.operationEpoch += 1
        let operation = core.operationEpoch
        core.latestOperation = operation
        operationBox?.value = operation
        var values = core.getSubmitValues()
        let inputsChanged = core.watchCheckedInputs(values)
        let stale = { epoch != core.validationEpoch || operation != core.operationEpoch || inputsChanged() }
        core.submitting = true
        core.notify()
        defer {
            if operation == core.operationEpoch {
                core.submitting = false
                core.notify()
            }
        }
        do {
            if stale() { return false }
            if !core.validate(navigate: true).isEmpty || stale() { return false }
            if let before = lifecycle.onBeforeSubmit {
                let allowed = try await before(values)
                if stale() || allowed == false { return false }
                if !core.validate(navigate: true).isEmpty || stale() { return false }
                values = core.getSubmitValues()
            }
            dispatched = true
            let skippedSteps = core.skipped.map(\.id)
            let sent = core.values
            let serverErrors = core.serverErrorsGeneration
            if keepSkipped, let step = core.currentStep { core.emit(.stepSkipped(stepId: step.id)) }
            core.emit(.formSubmitted(fieldCount: values.count))
            let result: SubmitResult?
            do {
                result = try await submit(values, skippedSteps)
            } catch {
                core.emit(.formSubmitFailed(reason: .error))
                throw error
            }
            let rejected = result?.isRejection == true
            core.emit(rejected ? .formSubmitFailed(reason: .rejected) : .formSubmitSucceeded)
            if operation != core.operationEpoch { return !rejected }
            if case .rejected(let errors, let formErrors)? = result {
                applyRejection(errors, formErrors, sent)
                return false
            }
            if core.serverErrorsGeneration == serverErrors { core.applyValidationErrors(FieldErrors(), server: true) }
            let submitted = values
            try await afterCommit(.afterSubmit) { try await lifecycle.onAfterSubmit?(submitted, skippedSteps) }
            return true
        } catch {
            if !dispatched && stale() { return false }
            throw error
        }
    }
}

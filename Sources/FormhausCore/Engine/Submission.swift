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
        var succeeded = false
        let epoch = core.validationEpoch
        let operation = core.beginOperation()
        operationBox?.value = operation
        let checked = core.getSubmitValues()
        let inputsChanged = core.watchCheckedInputs(checked)
        let stale = { epoch != core.validationEpoch || operation != core.operationEpoch || inputsChanged() }
        core.submitting = true
        core.notify()
        defer {
            if operation == core.latestOperation {
                core.submitting = false
                core.notify()
            }
        }
        do {
            guard let values = try await approveSubmission(checked, stale) else { return false }
            core.sending = operation
            let skippedSteps = core.skipped.map(\.id)
            let sent = core.values
            let serverErrors = core.serverErrorsGeneration
            if keepSkipped, let step = core.currentStep { core.emit(.stepSkipped(stepId: step.id)) }
            let result = try await send(submit, values, skippedSteps)
            if operation != core.operationEpoch { return result?.isRejection != true }
            guard accept(result, sent, serverErrors) else { return false }
            succeeded = true
            try await suspended { try await afterCommit(.afterSubmit) { try await options.onAfterSubmit?(values, skippedSteps) } }
            return true
        } catch is CancellationError {
            return succeeded
        } catch {
            if core.sending != operation && stale() { return false }
            throw error
        }
    }

    private func accept(_ result: SubmitResult?, _ sent: Values, _ serverErrors: Int) -> Bool {
        if case .rejected(let errors, let formErrors)? = result {
            applyRejection(errors, formErrors, sent)
            return false
        }
        if core.serverErrorsGeneration == serverErrors { core.applyValidationErrors(FieldErrors(), server: true) }
        return true
    }

    private func approveSubmission(_ checked: JSONObject, _ stale: () -> Bool) async throws -> JSONObject? {
        if stale() || invalid(stale) { return nil }
        guard let before = options.onBeforeSubmit else { return checked }
        let allowed = try await suspended { try await before(checked) }
        if stale() || allowed == false || invalid(stale) { return nil }
        return core.getSubmitValues()
    }

    private func invalid(_ stale: () -> Bool) -> Bool {
        if core.validate(navigate: true).isEmpty { return stale() }
        if !stale() { core.emit(.formSubmitFailed(reason: .validation)) }
        return true
    }

    private func send(_ submit: SubmitHandler, _ values: JSONObject, _ skippedSteps: [String]) async throws -> SubmitResult? {
        core.emit(.formSubmitted(fieldCount: values.count))
        let result: SubmitResult?
        do {
            result = try await suspended { try await submit(values, skippedSteps) }
        } catch {
            core.emit(.formSubmitFailed(reason: .error(status: submitStatus(error))))
            throw error
        }
        core.emit(result?.isRejection == true ? .formSubmitFailed(reason: .rejected) : .formSubmitSucceeded)
        return result
    }
}

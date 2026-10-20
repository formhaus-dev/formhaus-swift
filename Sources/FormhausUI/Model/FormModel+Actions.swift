@_spi(Renderer) import FormhausCore
import Foundation

extension FormModel {
    public func setValue(_ value: JSONValue?, forKey key: String) {
        guard !disabled else {
            if fieldStates[key]?.hasFocus == true { heldEdits[key] = .some(value) }
            return
        }
        heldEdits[key] = nil
        dropFocusRequest()
        engine.setValue(key, value)
        options.onFieldChange?(key, value, engine.values)
    }

    public func commitValue(_ value: JSONValue?, forKey key: String) {
        guard !disabled else { return }
        let step = engine.currentStep?.nodeID
        let field = engine.visibleFields.first { $0.key == key }
        setValue(value, forKey: key)
        guard field?.advancesOnCommit == true, engine.currentStep?.nodeID == step, !engine.isLastStep else { return }
        Task { await run { try await self.engine.autoAdvance() } }
    }

    @discardableResult
    func changeItems(ofGroup key: String, using apply: () -> Bool) -> Bool {
        guard !disabled, apply() else { return false }
        options.onFieldChange?(key, engine.values[key], engine.values)
        return true
    }

    public func next() async {
        await run {
            let action = self.engine.isLastStep ? nil : self.engine.currentStep?.next.action
            guard !isActionDisabled(action, self.engine.getSubmitValues()) else { return false }
            return try await self.engine.next()
        }
    }

    public func back() async {
        await run { try await self.engine.back() }
    }

    public func skip() async {
        await run { try await self.engine.skip(self.submitHandler) }
    }

    public func submit() async {
        await run {
            guard !isActionDisabled(self.engine.definition.submit, self.engine.getSubmitValues()) else { return false }
            return try await self.engine.submit(self.submitHandler)
        }
    }

    public func performPrimaryAction() async {
        if actions.isLastStep { await submit() } else { await next() }
    }

    public func cancel() {
        options.onCancel?()
    }

    public func setErrors(_ errors: FieldErrors) {
        engine.setErrors(errors)
        if !errors.isEmpty { requestFocus(engine.firstErrorKey(), afterErrors: true) }
    }

    @discardableResult
    public func goToStep(_ stepId: String) -> GoToStepResult {
        engine.goToStep(stepId)
    }

    public func focus(field key: String) {
        engine.goToStepWithField(key)
        requestFocus(key)
    }

    func run(_ action: @escaping @MainActor () async throws -> Bool) async {
        guard !loading else { return }
        setActionError(nil)
        let errors = engine.errorsVersion
        do {
            let done = try await action()
            if !done, engine.errorsVersion != errors, !engine.errors.isEmpty { noteInvalidAttempt() }
        } catch {
            if let onError = options.onError {
                onError(error)
            } else {
                setActionError(actionMessage(error))
            }
        }
        applyHeldEdits()
    }

    func loadingChanged() {
        refreshDisabled()
        applyHeldEdits()
    }

    private func applyHeldEdits() {
        guard !disabled, !heldEdits.isEmpty else { return }
        let edits = heldEdits
        heldEdits = [:]
        for (key, value) in edits { setValue(value, forKey: key) }
    }
}

private func actionMessage(_ error: any Error) -> String {
    if let error = error as? FormLifecycleError { return error.message }
    return (error as? LocalizedError)?.errorDescription ?? "Form action failed"
}

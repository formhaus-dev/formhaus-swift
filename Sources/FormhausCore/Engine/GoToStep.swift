public enum StepRedirectReason: String, Sendable {
    case blocked
    case notOnPath = "not-on-path"
    case unknownStep = "unknown-step"
}

public struct GoToStepResult: Sendable, Equatable {
    public let stepId: String?
    public let reached: Bool
    public let reason: StepRedirectReason?
}

extension FormEngine {
    @discardableResult
    public func goToStep(_ stepId: String) -> GoToStepResult {
        let core = core
        let steps = core.visibleSteps
        let current = core.currentStepIndex
        var order = StringMap<Int>()
        for (position, step) in (core.definition.steps ?? []).enumerated().reversed() { order[step.id] = position }
        let requested = core.isMultiStep ? order[stepId] : nil
        let index = steps.firstIndex { sameText($0.id, stepId) }
        let busy = core.stepValidating || core.submitting
        var target = current
        if let requested, !busy {
            target = index ?? (steps.count(where: { (order[$0.id] ?? 0) < requested }) - 1)
        }
        if current < target, let blocking = (current..<target).first(where: { blocks(steps[$0]) }) { target = blocking }
        target = max(target, 0)
        if target != current { moveTo(target) }
        let id = steps.indices.contains(target) ? steps[target].id : nil
        let reason = redirect(known: requested != nil, busy: busy, index: index, target: target)
        if let reason { core.emit(.stepRedirected(requestedStepId: stepId, stepId: id, reason: reason)) }
        return GoToStepResult(stepId: id, reached: reason == nil, reason: reason)
    }

    private func redirect(known: Bool, busy: Bool, index: Int?, target: Int) -> StepRedirectReason? {
        guard known else { return .unknownStep }
        guard let index else { return busy ? .blocked : .notOnPath }
        return busy || index != target ? .blocked : nil
    }

    private func blocks(_ step: FormStep) -> Bool {
        !core.isStepSkipped(step.id) && !core.fieldsErrors(step.fields).isEmpty
    }
}

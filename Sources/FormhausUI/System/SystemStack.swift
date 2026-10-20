@_spi(Renderer) import FormhausCore
import Foundation
import Observation
import SwiftUI

extension Notification.Name {
    static let formhausStepsReleased = Notification.Name("formhaus.stepsReleased")
}

#if os(iOS)
    struct StepSnapshot {
        let nodes: [FormNode]
        let step: FormStep?
    }
#endif

@MainActor
@Observable
final class StepStore {
    private(set) var history: [String] = []
    #if os(iOS)
        private(set) var snapshots: [String: StepSnapshot] = [:]
    #endif
    let token = UUID()
    #if os(iOS)
        @ObservationIgnored private var owner: ObjectIdentifier?
        @ObservationIgnored private var revision: Int?
    #endif
    @ObservationIgnored private var target: Int?

    isolated deinit {
        let token = token
        Task { @MainActor in
            NotificationCenter.default.post(name: .formhausStepsReleased, object: nil, userInfo: ["owner": token])
        }
    }

    func sync(_ model: FormModel) {
        let structure = model.structure
        let ids = path(structure)
        #if os(iOS)
            if owner != ObjectIdentifier(model) || revision != structure.revision {
                owner = ObjectIdentifier(model)
                revision = structure.revision
                snapshots = [:]
                for step in structure.steps.prefix(ids.count) {
                    snapshots[stepKey(step)] = StepSnapshot(nodes: model.engine.visibleNodes(of: step), step: step)
                }
            }
            if let current = ids.last { snapshots[current] = StepSnapshot(nodes: structure.nodes, step: structure.currentStep) }
        #endif
        if target == nil, history != ids { history = ids }
    }

    func release() {
        target = nil
        guard history.count > 1 else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { history = Array(history.prefix(1)) }
        NotificationCenter.default.post(name: .formhausStepsReleased, object: nil, userInfo: ["owner": token])
    }

    #if os(iOS)
        func pop(to level: Int, _ model: FormModel) {
            guard history.count > level + 1 else { return }
            history.removeSubrange((level + 1)...)
            if let target, target <= level { return }
            let running = target != nil
            target = level
            guard !running else { return }
            Task {
                while let target, model.structure.stepIndex > target {
                    let from = model.structure.stepIndex
                    await model.back()
                    if model.structure.stepIndex >= from { break }
                }
                target = nil
                sync(model)
            }
        }

        func snapshot(_ level: Int, _ model: FormModel) -> StepSnapshot {
            let structure = model.structure
            guard history.indices.contains(level) else { return StepSnapshot(nodes: [], step: nil) }
            let id = history[level]
            if level == history.count - 1, id == path(structure).last {
                return StepSnapshot(nodes: structure.nodes, step: structure.currentStep)
            }
            if let kept = snapshots[id] { return kept }
            let step = structure.steps.first { stepKey($0) == id }
            return StepSnapshot(nodes: step.map { model.engine.visibleNodes(of: $0) } ?? [], step: step)
        }
    #endif

    private func path(_ structure: FormStructure) -> [String] {
        guard structure.isMultiStep, structure.steps.indices.contains(structure.stepIndex) else { return ["form"] }
        return structure.steps.prefix(structure.stepIndex + 1).map(stepKey)
    }
}

private func stepKey(_ step: FormStep) -> String {
    "step:\(step.id)"
}

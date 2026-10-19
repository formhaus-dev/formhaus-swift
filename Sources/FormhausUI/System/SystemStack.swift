#if os(iOS)
    @_spi(Renderer) import FormhausCore
    import Observation
    import SwiftUI

    struct StepSnapshot {
        let nodes: [FormNode]
        let step: FormStep?
    }

    @MainActor
    @Observable
    final class StepStore {
        private(set) var history: [String] = []
        private(set) var snapshots: [String: StepSnapshot] = [:]
        let token = UUID()
        @ObservationIgnored private var owner: ObjectIdentifier?
        @ObservationIgnored private var target: Int?

        isolated deinit {
            let token = token
            Task { @MainActor in
                NotificationCenter.default.post(name: .formhausStepsReleased, object: nil, userInfo: ["owner": token])
            }
        }

        func sync(_ model: FormModel) {
            if owner != ObjectIdentifier(model) {
                owner = ObjectIdentifier(model)
                snapshots = [:]
            }
            let structure = model.structure
            let ids = path(structure)
            if let current = ids.last { snapshots[current] = StepSnapshot(nodes: structure.nodes, step: structure.currentStep) }
            if target == nil, history != ids { history = ids }
        }

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

        func snapshot(_ level: Int, _ structure: FormStructure) -> StepSnapshot {
            guard history.indices.contains(level) else { return StepSnapshot(nodes: [], step: nil) }
            let id = history[level]
            if level == history.count - 1, id == path(structure).last {
                return StepSnapshot(nodes: structure.nodes, step: structure.currentStep)
            }
            if let kept = snapshots[id] { return kept }
            let step = structure.steps.first { stepKey($0) == id }
            return StepSnapshot(nodes: step?.fields ?? [], step: step)
        }

        private func path(_ structure: FormStructure) -> [String] {
            guard structure.isMultiStep, structure.steps.indices.contains(structure.stepIndex) else { return ["form"] }
            return structure.steps.prefix(structure.stepIndex + 1).map(stepKey)
        }
    }

    private func stepKey(_ step: FormStep) -> String {
        "step:\(step.id)"
    }
#endif

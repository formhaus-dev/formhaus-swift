@MainActor
public final class DirtyTracker {
    private struct Baseline {
        let definition: FormDefinition
        let values: JSONObject
        let skipped: [(id: String, keys: [String])]
        var generation: Int
        var payload: JSONObject
    }

    private let engine: FormEngine
    private let listeners = Listeners()
    private var baseline: Baseline
    private var resetCount: Int
    private var unsubscribe: (@MainActor () -> Void)?
    public private(set) var dirtyKeys: [String] = []

    public init(engine: FormEngine) {
        self.engine = engine
        baseline = Self.capture(engine)
        resetCount = engine.resetCount
        unsubscribe = engine.subscribe { [weak self] in self?.update() }
    }

    public var isDirty: Bool { !dirtyKeys.isEmpty }

    public func markClean() {
        baseline = Self.capture(engine)
        resetCount = engine.resetCount
        update()
    }

    public func subscribe(_ listener: @escaping @MainActor () -> Void) -> @MainActor () -> Void {
        let id = listeners.add(listener)
        let listeners = listeners
        return { listeners.remove(id) }
    }

    public func stop() {
        unsubscribe?()
        unsubscribe = nil
    }

    private static func capture(_ engine: FormEngine) -> Baseline {
        Baseline(
            definition: engine.definition, values: engine.values, skipped: engine.core.skipped,
            generation: engine.core.definitionGeneration, payload: engine.getSubmitValues())
    }

    private func replayed() -> JSONObject {
        let shadow = EngineCore(
            definition: baseline.definition, values: baseline.values, validators: engine.options.validators,
            keep: engine.options.hiddenValues == .keep)
        shadow.skipped = baseline.skipped
        shadow.replaceDefinition(engine.definition)
        return shadow.getSubmitValues(payload: true)
    }

    private func update() {
        if resetCount != engine.resetCount { return markClean() }
        if baseline.generation != engine.core.definitionGeneration {
            baseline.payload = replayed()
            baseline.generation = engine.core.definitionGeneration
        }
        let next = changedKeys(baseline.payload, engine.getSubmitValues())
        if next.elementsEqual(dirtyKeys, by: sameText) { return }
        dirtyKeys = next
        listeners.fire()
    }
}

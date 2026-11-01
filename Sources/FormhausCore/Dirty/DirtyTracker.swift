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
    @_spi(Renderer) public private(set) var following: Bool
    public private(set) var dirtyKeys: [String] = []

    public convenience init(engine: FormEngine) {
        self.init(engine: engine, following: true)
    }

    @_spi(Renderer) public init(engine: FormEngine, following: Bool) {
        self.engine = engine
        self.following = following
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

    @_spi(Renderer) public func follow() {
        guard !following else { return }
        following = true
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
        guard following else { return }
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

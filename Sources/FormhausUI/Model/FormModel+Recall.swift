@_spi(Renderer) import FormhausCore

extension FormModel {
    func track(_ dependencies: [RecallDependency]) {
        guard !dependencies.isEmpty else { return }
        _ = structureVersion
        for dependency in dependencies {
            if dependency.isGroup {
                _ = group(dependency.key).items
            } else {
                _ = field(dependency.key).value
            }
        }
    }

    public func texts(for field: FormField, at key: String? = nil) -> RecalledTexts {
        track(engine.recallDependencies(field, at: key))
        return engine.recalledTexts(field, at: key)
    }

    public func texts(for section: FormSection) -> RecalledTexts {
        track(engine.recallDependencies(section))
        return engine.recalledTexts(section)
    }

    public func texts(for step: FormStep) -> RecalledTexts {
        track(engine.recallDependencies(step))
        return engine.recalledTexts(step)
    }
}

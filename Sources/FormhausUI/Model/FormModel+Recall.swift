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

    public func recalled(_ field: FormField, at key: String? = nil) -> FormField {
        track(engine.recallDependencies(field, at: key))
        return engine.recalled(field, at: key)
    }

    public func recalled(_ section: FormSection) -> FormSection {
        track(engine.recallDependencies(section))
        return engine.recalled(section)
    }

    public func recalled(_ step: FormStep) -> FormStep {
        track(engine.recallDependencies(step))
        return engine.recalled(step)
    }
}

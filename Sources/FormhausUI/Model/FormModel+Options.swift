@_spi(Renderer) import FormhausCore

extension FormModel {
    func optionKey(_ key: String) -> String {
        guard let path = engine.itemPath(key) else { return key }
        return "\(path.group).\(path.field)"
    }

    public func options(for key: String) -> [FieldOption]? {
        optionsState(optionKey(key)).options
    }

    private func optionsState(_ key: String) -> OptionsState {
        if let state = optionStates[key] { return state }
        let state = OptionsState()
        optionStates[key] = state
        return state
    }

    func reloadOptions() {
        guard !options.optionsProviders.isEmpty else { return }
        for (key, field) in optionSources() {
            guard let name = field.optionsFrom?.stringValue, let provider = options.optionsProviders[name] else { continue }
            let state = optionsState(key)
            let inputs = (field.optionsDependsOn ?? []).map { engine.values[$0] }
            guard state.inputs != inputs else { continue }
            state.inputs = inputs
            state.request += 1
            let request = state.request
            let values = engine.values
            Task {
                let loaded = await provider(values)
                if state.request == request { state.update(loaded) }
            }
        }
    }

    private func optionSources() -> [(String, FormField)] {
        structure.visibleFields.flatMap { field -> [(String, FormField)] in
            guard field.isGroup else { return [(field.key, field)] }
            return field.items.map { ("\(field.key).\($0.key)", $0) }
        }
    }
}

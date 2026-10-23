@_spi(Renderer) import FormhausCore

@MainActor
final class HookBox {
    var current: FormEngineOptions

    init(_ options: FormEngineOptions) {
        current = options
    }

    func forwarding() -> FormEngineOptions {
        var options = current
        options.onBeforeStepChange = { [self] context in
            guard let hook = current.onBeforeStepChange else { return nil }
            return try await hook(context)
        }
        options.onAfterStepChange = { [self] in try await current.onAfterStepChange?($0) }
        options.onBeforeSubmit = { [self] values in
            guard let hook = current.onBeforeSubmit else { return nil }
            return try await hook(values)
        }
        options.onAfterSubmit = { [self] in try await current.onAfterSubmit?($0, $1) }
        options.onStepValidate = { [self] step, values in
            guard let hook = current.onStepValidate else { return nil }
            return try await hook(step, values)
        }
        options.onValidate = { [self] values, context in
            guard let hook = current.onValidate else { return nil }
            return try await hook(values, context)
        }
        if current.onFormEvent != nil { options.onFormEvent = { [self] in current.onFormEvent?($0) } }
        return options
    }
}

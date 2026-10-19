@_spi(Renderer) import FormhausCore
import SwiftUI

public struct FormhausForm: View {
    @State private var holder = ModelHolder()
    private let make: @MainActor () -> FormModel

    public init(model: FormModel) {
        make = { model }
    }

    public init(
        definition: FormDefinition, initialValues: JSONObject = JSONObject(), options: FormEngineOptions = FormEngineOptions(),
        renderer: FormRendererOptions = FormRendererOptions(), onSubmit: @escaping SubmitHandler
    ) {
        make = {
            FormModel(definition: definition, initialValues: initialValues, engineOptions: options, options: renderer, onSubmit: onSubmit)
        }
    }

    public var body: some View {
        let model = holder.resolve(make)
        FormScroller(model: model).resolveFormhausTokens()
    }
}

@MainActor
private final class ModelHolder {
    private var model: FormModel?

    func resolve(_ make: () -> FormModel) -> FormModel {
        if let model { return model }
        let created = make()
        model = created
        return created
    }
}

private struct FormScroller: View {
    @Environment(\.formhausTokens) private var tokens
    let model: FormModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                FormhausFormContent(model: model)
                    .padding(tokens.spacing.s10)
                    .frame(maxWidth: tokens.controls.maxWidth)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.focusRequest) { _, request in
                guard let key = request?.key else { return }
                withAnimation(tokens.animation(tokens.motion.progress)) { proxy.scrollTo(key, anchor: .center) }
            }
        }
        .background(tokens.colors.background)
    }
}

public struct FormhausFormContent: View {
    let model: FormModel

    public init(model: FormModel) {
        self.model = model
    }

    public var body: some View {
        FormStack(model: model)
            .formLocale(model.definition.lang)
            .onAppear { model.start() }
            .resolveFormhausTokens()
    }
}

private struct FormStack: View {
    @Environment(\.formhausTokens) private var tokens
    let model: FormModel

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacing.gap) {
            FormFields(model: model)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    @ViewBuilder
    fileprivate func formLocale(_ lang: String?) -> some View {
        if let lang, !lang.isEmpty {
            environment(\.locale, Locale(identifier: lang))
        } else {
            self
        }
    }
}

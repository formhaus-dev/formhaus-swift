@_spi(Renderer) import FormhausCore
import SwiftUI

public struct FormhausForm: View {
    @State private var holder = ModelHolder()
    private let source: ModelSource

    public init(model: FormModel) {
        source = .model(model)
    }

    public init(
        definition: FormDefinition, initialValues: JSONObject = JSONObject(), options: FormEngineOptions = FormEngineOptions(),
        renderer: FormRendererOptions = FormRendererOptions(), onSubmit: @escaping SubmitHandler
    ) {
        source = .definition(
            OwnedForm(definition: definition, values: initialValues, engine: options, renderer: renderer, submit: onSubmit))
    }

    public var body: some View {
        let model = holder.resolve(source)
        FormScroller(model: model)
            .id(ObjectIdentifier(model))
            .resolveFormhausTokens()
    }
}

struct OwnedForm {
    let definition: FormDefinition
    let values: JSONObject
    let engine: FormEngineOptions
    let renderer: FormRendererOptions
    let submit: SubmitHandler
}

enum ModelSource {
    case model(FormModel)
    case definition(OwnedForm)
}

@MainActor
final class ModelHolder {
    private var model: FormModel?
    private var owned = false
    private var definition: JSONObject?
    private nonisolated(unsafe) var cancel: (@MainActor () -> Void)?

    deinit {
        guard let cancel else { return }
        Task { @MainActor in cancel() }
    }

    func resolve(_ source: ModelSource) -> FormModel {
        switch source {
        case .model(let given):
            if model !== given { replace(given, owned: false, definition: nil) }
            return given
        case .definition(let form):
            if let model, owned, definition == form.definition.source {
                model.updateHandlers(engineOptions: form.engine, options: form.renderer, onSubmit: form.submit)
                return model
            }
            let created = FormModel(
                definition: form.definition, initialValues: form.values, engineOptions: form.engine, options: form.renderer,
                onSubmit: form.submit)
            replace(created, owned: true, definition: form.definition.source)
            return created
        }
    }

    private func replace(_ next: FormModel, owned isOwned: Bool, definition source: JSONObject?) {
        cancel?()
        model = next
        owned = isOwned
        definition = source
        let engine = next.engine
        if isOwned {
            cancel = { @MainActor in engine.cancelPendingActions() }
        } else {
            cancel = nil
        }
    }
}

private struct FormScroller: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.formhausComponents) private var components
    @State private var topRequests = TopRequests()
    let model: FormModel

    var body: some View {
        if components.system {
            FormhausFormContent(model: model)
        } else {
            scroller
        }
    }

    private var scroller: some View {
        ScrollViewReader { proxy in
            ScrollView {
                FormhausFormContent(model: model)
                    .padding(tokens.spacing.s10)
                    .frame(maxWidth: tokens.controls.maxWidth)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .top) { Color.clear.frame(height: 1).id(ScrollAnchor.screenTop(model)) }
            }
            .modifier(ScreenTopScroller(requests: topRequests, proxy: proxy, anchor: ScrollAnchor.screenTop(model)))
        }
        .environment(\.formhausTopRequests, topRequests)
        .scrollDismissesKeyboard(.interactively)
        .background(tokens.colors.background)
    }
}

public struct FormhausFormContent: View {
    @Environment(\.formhausComponents) private var components
    let model: FormModel

    public init(model: FormModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            if components.system {
                SystemForm(model: model)
            } else {
                ScrollViewReader { proxy in
                    FormStack(model: model)
                        .modifier(StepScroller(model: model, proxy: proxy))
                        .sensoryFeedback(.error, trigger: model.invalidAttempts)
                }
            }
        }
        .formLocale(model.definition.lang)
        .onAppear { model.start() }
        .resolveFormhausTokens()
    }
}

private struct FormStack: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.formhausBehavior) private var behavior
    let model: FormModel

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacing.gap) {
            FormProgress(model: model)
            FormFields(model: model)
            FormTopLevelErrors(model: model)
            if behavior.errorSummary { FormErrorSummary(model: model) }
            FormActionsSlot(model: model)
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

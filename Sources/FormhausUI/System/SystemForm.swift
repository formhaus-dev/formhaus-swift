@_spi(Renderer) import FormhausCore
import SwiftUI

@MainActor
private final class ShownModel {
    weak var model: FormModel?
}

struct SystemForm: View {
    @State private var shown = ShownModel()
    let model: FormModel

    var body: some View {
        let store = model.systemStack
        page(store)
            .onAppear { show() }
            .onChange(of: model.structure) { store.sync(model) }
            .onChange(of: ObjectIdentifier(model)) { show() }
    }

    private func show() {
        if let previous = shown.model, previous !== model { previous.systemStack.release() }
        shown.model = model
        model.systemStack.sync(model)
    }

    @ViewBuilder private func page(_ store: StepStore) -> some View {
        #if os(iOS)
            SystemStepPage(model: model, level: 0, owner: store.token, store: store)
        #else
            SystemPage(
                model: model, nodes: model.structure.nodes, step: model.structure.currentStep, level: model.structure.stepIndex,
                current: true)
        #endif
    }
}

#if os(iOS)
    private struct SystemStepPage: View {
        @Environment(\.formhausComponents) private var components
        @Environment(\.formhausBehavior) private var behavior
        @Environment(\.formhausTheme) private var theme
        @Environment(\.locale) private var locale
        let model: FormModel
        let level: Int
        let owner: UUID
        weak var store: StepStore?

        var body: some View {
            page.background { if level > 0 { StackReleaser(owner: owner, level: level) } }
        }

        @ViewBuilder private var page: some View {
            if let active = store {
                let snapshot = active.snapshot(level, model)
                SystemPage(
                    model: model, nodes: snapshot.nodes, step: snapshot.step, level: level, current: active.history.count == level + 1
                )
                .navigationDestination(isPresented: pushed) {
                    SystemStepPage(model: model, level: level + 1, owner: owner, store: self.store)
                        .formhausComponents(components)
                        .formhausBehavior(behavior)
                        .formhausTheme(theme)
                        .environment(\.locale, locale)
                        .resolveFormhausTokens()
                }
            } else {
                Color.clear
            }
        }

        private var pushed: Binding<Bool> {
            Binding(
                get: { [weak store] in (store?.history.count ?? 0) > level + 1 },
                set: { [weak store] shown in
                    guard !shown, let store, store.history.count > level + 1 else { return }
                    store.pop(to: level, model)
                })
        }
    }
#endif

struct SystemPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.formhausBehavior) private var behavior
    @Environment(\.formhausComponents) private var components
    @State private var dismissed = -1
    let model: FormModel
    let nodes: [FormNode]
    let step: FormStep?
    let level: Int
    let current: Bool

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                if current, components.slots.progress != nil { Section { FormProgress(model: model).listRowBackground(Color.clear) } }
                SystemStepHeader(model: model, step: step, level: level)
                if current { SystemErrorSummary(model: model) }
                SystemNodes(nodes: nodes.filter { $0.type != "hidden" }, model: model).id(model.structure.revision)
                if current { SystemSkip(model: model) }
                if current, let custom = components.slots.actions {
                    Section { custom(actions).listRowBackground(Color.clear) }
                } else if current {
                    #if os(macOS)
                        SystemBottomRow(context: actions)
                    #endif
                }
            }
            .formStyle(.grouped)
            .scrollDismissesKeyboard(.interactively)
            .sensoryFeedback(.error, trigger: model.invalidAttempts)
            .onChange(of: model.focusRequest) { _, request in
                guard current, let request, let key = request.key else { return }
                let summary = request.summary && behavior.errorSummary
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    proxy.scrollTo(summary ? ScrollAnchor.summary(model) : key, anchor: summary ? .top : .center)
                }
            }
            .onChange(of: current) { _, now in
                guard now, let request = model.focusRequest, let key = request.key else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard model.focusRequest?.key == key else { return }
                    model.requestFocus(key, afterErrors: request.summary)
                }
            }
        }
        .modifier(SystemStepTitle(title: model.definition.title))
        #if os(iOS)
            .modifier(SystemToolbar(context: actions, first: level == 0, empty: nodes.isEmpty, custom: components.slots.actions != nil))
        #endif
        .alert(errors.first ?? "", isPresented: alertShown) {
            Button(model.text(forLabel: "close"), role: .cancel) { dismissed = model.alertVersion }
        } message: {
            Text(verbatim: errors.dropFirst().joined(separator: "\n"))
        }
    }

    private var actions: ActionsContext {
        ActionsContext(state: model.actions, busy: model.disabled, model: model)
    }

    private var errors: [String] {
        model.topLevelErrors + (model.actionError.map { [$0] } ?? [])
    }

    private var alertShown: Binding<Bool> {
        Binding(
            get: { current && !errors.isEmpty && model.alertVersion != dismissed },
            set: { shown in if !shown { dismissed = model.alertVersion } })
    }
}

private struct SystemStepTitle: ViewModifier {
    let title: String?

    func body(content: Content) -> some View {
        if let title, !title.isEmpty {
            content.navigationTitle(Text(verbatim: title))
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.large)
                #endif
        } else {
            content
        }
    }
}

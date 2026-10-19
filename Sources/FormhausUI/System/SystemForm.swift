@_spi(Renderer) import FormhausCore
import SwiftUI

struct SystemForm: View {
    @State private var history: [String] = []
    let model: FormModel

    var body: some View {
        Group {
            #if os(iOS)
                SystemStepPage(model: model, level: 0, history: $history)
            #else
                SystemPage(
                    model: model, nodes: model.structure.nodes, step: model.structure.currentStep, level: model.structure.stepIndex,
                    current: true)
            #endif
        }
        .onAppear {
            if history.isEmpty { history = visited(model) } else { sync(stepID(model)) }
        }
        .onChange(of: stepID(model)) { _, id in sync(id) }
    }

    private func sync(_ id: String) {
        if let index = history.firstIndex(of: id) {
            history.removeSubrange((index + 1)...)
        } else {
            history.append(id)
        }
    }
}

@MainActor
private func visited(_ model: FormModel) -> [String] {
    let structure = model.structure
    guard structure.isMultiStep, structure.steps.indices.contains(structure.stepIndex) else { return [stepID(model)] }
    return structure.steps.prefix(structure.stepIndex + 1).filter { !model.engine.isStepSkipped($0.id) }.map { "step:\($0.id)" }
}

@MainActor
func stepID(_ model: FormModel) -> String {
    model.structure.currentStep.map { "step:\($0.id)" } ?? "form"
}

#if os(iOS)
    private struct SystemStepPage: View {
        @Environment(\.formhausComponents) private var components
        @Environment(\.formhausBehavior) private var behavior
        @Environment(\.formhausTheme) private var theme
        @Environment(\.locale) private var locale
        @State private var nodes: [FormNode] = []
        @State private var step: FormStep?
        let model: FormModel
        let level: Int
        @Binding var history: [String]

        var body: some View {
            let current = history.count == level + 1
            let structure = model.structure
            SystemPage(
                model: model, nodes: current ? structure.nodes : nodes, step: current ? structure.currentStep : step, level: level,
                current: current
            )
            .onAppear {
                if current {
                    keep(structure)
                } else if history.indices.contains(level) {
                    step = structure.steps.first { "step:\($0.id)" == history[level] }
                    nodes = step?.fields ?? []
                }
            }
            .onChange(of: structure.nodes.map(\.nodeID)) { if current { keep(model.structure) } }
            .navigationDestination(isPresented: pushed) {
                SystemStepPage(model: model, level: level + 1, history: $history)
                    .formhausComponents(components)
                    .formhausBehavior(behavior)
                    .formhausTheme(theme)
                    .environment(\.locale, locale)
                    .resolveFormhausTokens()
            }
        }

        private func keep(_ structure: FormStructure) {
            nodes = structure.nodes
            step = structure.currentStep
        }

        private var pushed: Binding<Bool> {
            Binding(
                get: { history.count > level + 1 },
                set: { shown in
                    guard !shown, history.count > level + 1 else { return }
                    history.removeSubrange((level + 1)...)
                    Task { await model.back() }
                })
        }
    }
#endif

struct SystemPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dismissed: [String] = []
    let model: FormModel
    @Environment(\.formhausComponents) private var components
    let nodes: [FormNode]
    let step: FormStep?
    let level: Int
    let current: Bool

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                if current, components.slots.progress != nil { Section { FormProgress(model: model).listRowBackground(Color.clear) } }
                SystemNodes(nodes: nodes.filter { $0.type != "hidden" }, model: model)
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
                guard current, let key = request?.key else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo(key, anchor: .center) }
            }
        }
        .modifier(SystemStepTitle(model: model, step: step, level: level))
        #if os(iOS)
            .modifier(SystemToolbar(context: actions, first: level == 0, empty: nodes.isEmpty, custom: components.slots.actions != nil))
        #endif
        .alert(errors.first ?? "", isPresented: alertShown) {
            Button(model.text(forLabel: "close"), role: .cancel) { dismissed = errors }
        } message: {
            Text(errors.dropFirst().joined(separator: "\n"))
        }
    }

    private var actions: ActionsContext {
        ActionsContext(state: model.actions, busy: model.disabled, model: model)
    }

    private var errors: [String] {
        model.topLevelErrors + (model.actionError.map { [$0] } ?? [])
    }

    private var alertShown: Binding<Bool> {
        Binding(get: { current && !errors.isEmpty && errors != dismissed }, set: { shown in if !shown { dismissed = errors } })
    }
}

private struct SystemStepTitle: ViewModifier {
    let model: FormModel
    let step: FormStep?
    let level: Int

    func body(content: Content) -> some View {
        if let step, model.structure.isMultiStep {
            let subtitle = model.text(forLabel: "stepTitle", ["index": .number(Double(level + 1))])
            if #available(iOS 26, macOS 14, *) {
                content.navigationTitle(step.title ?? subtitle).navigationSubtitle(step.title == nil ? "" : subtitle)
            } else {
                content.navigationTitle(step.title ?? subtitle)
            }
        } else {
            content
        }
    }
}

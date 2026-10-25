@_spi(Renderer) import FormhausCore
import SwiftUI

@MainActor
private final class StepDirection {
    var index = 0
    var forward = true
}

struct SystemForm: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.formhausBehavior) private var behavior
    @State private var direction = StepDirection()
    @State private var dismissed = -1
    let model: FormModel

    var body: some View {
        let structure = model.structure
        let index = structure.stepIndex
        if index != direction.index {
            direction.forward = index > direction.index
            direction.index = index
        }
        return ZStack {
            SystemPage(model: model, actions: actions, nodes: structure.nodes, step: structure.currentStep, level: index)
                .id(index)
                .transition(StepSlide(direction: direction))
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: index)
        .modifier(SystemStepTitle(title: model.definition.title, mode: behavior.titleDisplayMode))
        #if os(iOS)
            .modifier(SystemToolbar(context: actions, first: index == 0, empty: structure.nodes.isEmpty))
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
            get: { !errors.isEmpty && model.alertVersion != dismissed },
            set: { shown in if !shown { dismissed = model.alertVersion } })
    }
}

private struct StepSlide: Transition {
    let direction: StepDirection

    func body(content: Content, phase: TransitionPhase) -> some View {
        let sign: CGFloat = direction.forward ? 1 : -1
        let shift = phase == .willAppear ? sign : phase == .didDisappear ? -sign * 0.3 : 0
        content
            .visualEffect { view, proxy in view.offset(x: proxy.size.width * shift) }
            .zIndex(phase == .didDisappear ? 0 : 1)
    }
}

struct SystemPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.formhausBehavior) private var behavior
    @Environment(\.formhausComponents) private var components
    let model: FormModel
    let actions: ActionsContext
    let nodes: [FormNode]
    let step: FormStep?
    let level: Int

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                if components.slots.progress != nil { Section { FormProgress(model: model).listRowBackground(Color.clear) } }
                SystemStepHeader(model: model, step: step, level: level)
                SystemErrorSummary(model: model)
                SystemNodes(nodes: nodes.filter { $0.type != "hidden" }, model: model).id(model.structure.revision)
                SystemSkip(model: model)
                if let custom = components.slots.actions {
                    Section { custom(actions).listRowBackground(Color.clear) }
                } else {
                    SystemBottomRow(context: actions)
                }
            }
            .formStyle(.grouped)
            .formhausTestId(model.testId(.form))
            .scrollDismissesKeyboard(.interactively)
            .sensoryFeedback(.error, trigger: model.invalidAttempts)
            .onChange(of: model.focusRequest) { _, request in
                guard let request, let target = ScrollTarget.focus(request, summary: behavior.errorSummary) else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    if case .field(let key) = target { proxy.scrollTo(key) } else { target.scroll(proxy, model: model) }
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    model.refocus(request)
                }
            }
        }
    }
}

private struct SystemStepTitle: ViewModifier {
    let title: String?
    let mode: TitleDisplayMode

    func body(content: Content) -> some View {
        if let title, !title.isEmpty, mode != .off {
            #if os(iOS)
                switch mode {
                case .inline: content.navigationTitle(Text(verbatim: title)).navigationBarTitleDisplayMode(.inline)
                case .large: content.navigationTitle(Text(verbatim: title)).navigationBarTitleDisplayMode(.large)
                default: content.navigationTitle(Text(verbatim: title))
                }
            #else
                content.navigationTitle(Text(verbatim: title))
            #endif
        } else {
            content
        }
    }
}

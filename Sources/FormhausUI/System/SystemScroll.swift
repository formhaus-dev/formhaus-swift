@_spi(Renderer) import FormhausCore
import SwiftUI

private let textInputTypes: Set = ["text", "email", "phone", "number", "password", "autocomplete", "textarea"]

struct ScrollStep {
    let id: String
    let anchor: UnitPoint?
}

extension FormModel {
    var focusedKey: String? { fieldStates.first { $0.value.hasFocus }?.key }

    func refocus(_ request: FocusRequest) -> Bool {
        guard focusRequest == request, !request.summary, let key = request.key, focusedKey == nil,
            structure.visibleFields.contains(where: { $0.key == key && textInputTypes.contains($0.type) })
        else { return false }
        field(key).requestFocus(request.id)
        return true
    }

    func scrollSteps(to key: String) -> [ScrollStep] {
        let keys = structure.visibleFields.filter { $0.type != "hidden" }.map(\.key)
        guard let index = keys.firstIndex(of: key), index > 0 else {
            return [ScrollStep(id: key, anchor: keys.first == key ? .center : nil)]
        }
        return [ScrollStep(id: keys[index - 1], anchor: index == 1 ? .center : .top), ScrollStep(id: key, anchor: nil)]
    }
}

struct SystemFocusScroll: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.formhausBehavior) private var behavior
    @State private var task: Task<Void, Never>?
    @State private var keyboardKey: String?
    let model: FormModel
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        content
            .onChange(of: model.focusRequest) { _, request in
                task?.cancel()
                keyboardKey = nil
                guard let request, let target = ScrollTarget.focus(request, summary: behavior.errorSummary) else { return }
                task = Task { await scroll(to: target, for: request) }
            }
            .onChange(of: model.structure.stepIndex) { task?.cancel() }
            .onDisappear { task?.cancel() }
            #if os(iOS)
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    guard let key = keyboardKey else { return }
                    keyboardKey = nil
                    guard model.focusedKey == key else { return }
                    withAnimation(animation) { proxy.scrollTo(key) }
                }
            #endif
    }

    private var animation: Animation? { reduceMotion ? nil : .easeOut(duration: 0.2) }

    private func scroll(to target: ScrollTarget, for request: FocusRequest) async {
        guard case .field(let key) = target else {
            withAnimation(animation) { target.scroll(proxy, model: model) }
            return
        }
        keyboardKey = key
        let steps = model.scrollSteps(to: key)
        for (index, step) in steps.enumerated() {
            if index > 0 { await Task.yield() }
            guard !Task.isCancelled else { return }
            withAnimation(index == steps.count - 1 ? animation : nil) { proxy.scrollTo(step.id, anchor: step.anchor) }
        }
        for _ in 0..<3 {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, model.refocus(request) else { return }
        }
    }
}

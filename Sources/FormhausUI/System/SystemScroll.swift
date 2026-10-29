@_spi(Renderer) import FormhausCore
import SwiftUI

private let textInputTypes: Set = ["text", "email", "phone", "number", "password", "autocomplete", "textarea"]

struct ScrollStep {
    let id: String
    let anchor: UnitPoint?
}

@MainActor
final class VisibleRows {
    private(set) var visible: Set<String> = []
    private(set) var questions: Set<String> = []

    func update(_ id: String, visible shown: Bool) {
        if shown { visible.insert(id) } else { visible.remove(id) }
    }

    func noteQuestion(_ key: String) {
        questions.insert(key)
    }

    func shows(_ key: String) -> Bool {
        visible.contains(key) && (!questions.contains(key) || visible.contains(Self.question(key)))
    }

    static func question(_ key: String) -> String { "\(key)#question" }
}

extension EnvironmentValues {
    @Entry var formhausVisibleRows: VisibleRows?
}

private struct VisibilityProbe: ViewModifier {
    @Environment(\.formhausVisibleRows) private var rows
    let id: String
    let question: String?

    func body(content: Content) -> some View {
        if #available(iOS 18, macOS 15, *), let rows {
            content
                .onAppear { if let question { rows.noteQuestion(question) } }
                .onScrollVisibilityChange(threshold: 0.99) { rows.update(id, visible: $0) }
                .onDisappear { rows.update(id, visible: false) }
        } else {
            content
        }
    }
}

extension View {
    func scrollVisibility(_ id: String) -> some View {
        modifier(VisibilityProbe(id: id, question: nil))
    }

    func questionVisibility(_ key: String) -> some View {
        modifier(VisibilityProbe(id: VisibleRows.question(key), question: key))
    }
}

extension FormModel {
    var focusedKey: String? { fieldStates.first { $0.value.hasFocus }?.key }

    private var focusOrder: [(key: String, field: FormField)] {
        structure.visibleFields.filter { $0.type != "hidden" }.flatMap { field -> [(key: String, field: FormField)] in
            guard field.isGroup else { return [(field.key, field)] }
            return engine.items(field.key).enumerated().flatMap { index, item in
                item.fields.filter { $0.type != "hidden" }.map { ("\(field.key).\(index).\($0.key)", $0) }
            }
        }
    }

    func refocus(_ request: FocusRequest, errorSummary: Bool, replacing previous: String?) -> Bool {
        guard focusRequest == request, !(request.summary && errorSummary), let key = request.key,
            focusedKey == nil || focusedKey == previous && previous != key,
            focusOrder.contains(where: { $0.key == key && textInputTypes.contains($0.field.type) })
        else { return false }
        field(key).requestFocus(request.id)
        return true
    }

    func scrollSteps(to key: String) -> [ScrollStep] {
        let keys = focusOrder.map(\.key)
        guard let index = keys.firstIndex(of: key), index > 0 else {
            return [ScrollStep(id: key, anchor: keys.first == key ? .center : nil)]
        }
        return [ScrollStep(id: keys[index - 1], anchor: index == 1 ? .center : .top), ScrollStep(id: key, anchor: nil)]
    }
}

struct SystemFocusScroll: ViewModifier {
    @ScrollMotion private var animation
    @Environment(\.formhausBehavior) private var behavior
    @State private var task: Task<Void, Never>?
    @State private var keyboardKey: String?
    #if os(iOS)
        @State private var keyboardShown = false
    #endif
    @State private var rows = VisibleRows()
    let model: FormModel
    let proxy: ScrollViewProxy
    let reveal: (String) -> RevealScroll?

    func body(content: Content) -> some View {
        content
            .environment(\.formhausVisibleRows, rows)
            .onChange(of: model.focusRequest) { _, request in
                stop()
                guard let request, let target = ScrollTarget.focus(request, summary: behavior.errorSummary) else { return }
                let previous = model.focusedKey
                task = Task { await scroll(to: target, for: request, replacing: previous) }
            }
            .onChange(of: model.structure.stepIndex) { stop() }
            .onDisappear { stop() }
            #if os(iOS)
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    keyboardShown = true
                    showFocusedField()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    keyboardShown = false
                }
                .onChange(of: keyboardKey.map { model.field($0).hasFocus } ?? false) { showFocusedField() }
            #endif
    }

    #if os(iOS)
        private func showFocusedField() {
            guard let key = keyboardKey, let focused = model.focusedKey else { return }
            guard focused == key else {
                keyboardKey = nil
                return
            }
            guard keyboardShown else { return }
            keyboardKey = nil
            let revealed = reveal(key)
            withAnimation(animation) { proxy.scrollTo(revealed?.row ?? key, anchor: revealed?.anchor) }
        }
    #endif

    private func stop() {
        task?.cancel()
        keyboardKey = nil
    }

    private func scroll(to target: ScrollTarget, for request: FocusRequest, replacing previous: String?) async {
        guard case .field(let key) = target else {
            withAnimation(animation) { target.scroll(proxy, model: model) }
            return
        }
        keyboardKey = key
        let revealed = reveal(key)
        if !rows.shows(revealed?.row ?? key) {
            let steps =
                model.scrollSteps(to: revealed?.choice ?? key) + (revealed.map { [ScrollStep(id: $0.row, anchor: $0.anchor)] } ?? [])
            for (index, step) in steps.enumerated() {
                if index > 0 { await Task.yield() }
                guard !Task.isCancelled else { return }
                withAnimation(index == steps.count - 1 ? animation : nil) { proxy.scrollTo(step.id, anchor: step.anchor) }
            }
        }
        for _ in 0..<3 {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, model.refocus(request, errorSummary: behavior.errorSummary, replacing: previous) else { return }
        }
    }
}

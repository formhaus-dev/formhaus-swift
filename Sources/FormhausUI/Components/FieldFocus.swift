import SwiftUI

private struct FocusRequestReader: ViewModifier {
    @Environment(\.formhausBehavior) private var behavior
    let state: FieldState
    let model: FormModel
    let disabled: Bool
    let perform: @MainActor () -> Void
    @State private var waiting: Int?

    func body(content: Content) -> some View {
        content
            .onAppear { receive() }
            .onChange(of: state.focusToken) { receive() }
            .onChange(of: disabled) { apply() }
    }

    private func receive() {
        if let id = state.takeFocusRequest() { waiting = id }
        apply()
    }

    private func apply() {
        guard let id = waiting, !disabled else { return }
        waiting = nil
        guard let request = model.focusRequest, request.id == id, !(request.summary && behavior.errorSummary) else { return }
        perform()
    }
}

private struct FieldFocus: ViewModifier {
    let context: FieldContext
    let focused: FocusState<Bool>.Binding
    @AccessibilityFocusState private var spoken: Bool

    func body(content: Content) -> some View {
        content
            .focused(focused)
            .accessibilityFocused($spoken)
            .onFormhausFocus(context) {
                focused.wrappedValue = true
                spoken = true
            }
            .notesFocus(context, focused.wrappedValue)
    }
}

extension View {
    public func formhausFocus(_ context: FieldContext, _ focused: FocusState<Bool>.Binding) -> some View {
        modifier(FieldFocus(context: context, focused: focused))
    }

    public func onFormhausFocus(_ context: FieldContext, perform: @escaping @MainActor () -> Void) -> some View {
        modifier(FocusRequestReader(state: context.state, model: context.model, disabled: context.isLocked, perform: perform))
    }

    public func formhausScrollAnchor(_ context: FieldContext) -> some View {
        id(context.key)
    }

    func notesFocus(_ context: FieldContext, _ focused: Bool) -> some View {
        onChange(of: focused) { _, now in context.state.noteFocus(now) }
            .onDisappear { context.state.noteFocus(false) }
    }

    func onFormhausFocus(_ state: FieldState, model: FormModel, disabled: Bool, perform: @escaping @MainActor () -> Void) -> some View {
        modifier(FocusRequestReader(state: state, model: model, disabled: disabled, perform: perform))
    }
}

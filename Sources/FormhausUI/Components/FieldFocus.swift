import SwiftUI

private struct FocusRequestReader: ViewModifier {
    let state: FieldState
    let disabled: Bool
    let perform: @MainActor () -> Void
    @State private var waiting = false

    func body(content: Content) -> some View {
        content
            .onAppear { receive() }
            .onChange(of: state.focusToken) { receive() }
            .onChange(of: disabled) { apply() }
    }

    private func receive() {
        if state.takeFocusRequest() { waiting = true }
        apply()
    }

    private func apply() {
        guard waiting, !disabled else { return }
        waiting = false
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
    }
}

extension View {
    public func formhausFocus(_ context: FieldContext, _ focused: FocusState<Bool>.Binding) -> some View {
        modifier(FieldFocus(context: context, focused: focused))
    }

    public func onFormhausFocus(_ context: FieldContext, perform: @escaping @MainActor () -> Void) -> some View {
        modifier(FocusRequestReader(state: context.state, disabled: context.isLocked, perform: perform))
    }

    public func formhausScrollAnchor(_ context: FieldContext) -> some View {
        id(context.key)
    }

    func onFormhausFocus(_ state: FieldState, disabled: Bool, perform: @escaping @MainActor () -> Void) -> some View {
        modifier(FocusRequestReader(state: state, disabled: disabled, perform: perform))
    }
}

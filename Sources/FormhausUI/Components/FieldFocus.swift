import SwiftUI

struct FieldFocus: ViewModifier {
    let token: Int
    let disabled: Bool
    let focused: FocusState<Bool>.Binding
    @AccessibilityFocusState private var spoken: Bool
    @State private var pending = false

    func body(content: Content) -> some View {
        content
            .focused(focused)
            .accessibilityFocused($spoken)
            .onChange(of: token) {
                pending = true
                apply()
            }
            .onChange(of: disabled) { apply() }
    }

    private func apply() {
        guard pending, !disabled else { return }
        pending = false
        focused.wrappedValue = true
        spoken = true
    }
}

extension View {
    func fieldFocus(_ context: FieldContext, _ focused: FocusState<Bool>.Binding) -> some View {
        modifier(FieldFocus(token: context.state.focusToken, disabled: context.isLocked, focused: focused))
    }
}

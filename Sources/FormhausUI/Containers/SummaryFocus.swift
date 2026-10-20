import SwiftUI

struct SummaryFocus: ViewModifier {
    @AccessibilityFocusState private var focused: Bool
    @State private var handled: Int?
    let model: FormModel

    func body(content: Content) -> some View {
        content
            .accessibilityFocused($focused)
            .onAppear { take() }
            .onChange(of: model.focusRequest) { take() }
    }

    private func take() {
        guard let request = model.focusRequest, request.summary, request.id != handled else { return }
        handled = request.id
        focused = true
    }
}

extension View {
    func formhausSummaryFocus(_ model: FormModel) -> some View {
        modifier(SummaryFocus(model: model))
    }
}

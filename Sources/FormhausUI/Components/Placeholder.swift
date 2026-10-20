import SwiftUI

struct Placeholder: ViewModifier {
    @Environment(\.formhausTokens) private var tokens
    let text: String?
    let visible: Bool

    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            if visible, let text, !text.isEmpty {
                Text(verbatim: text)
                    .formhausText(.body, colored: false)
                    .foregroundStyle(tokens.colors.control)
                    .lineLimit(1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func placeholder(_ text: String?, visible: Bool) -> some View {
        modifier(Placeholder(text: text, visible: visible))
    }
}

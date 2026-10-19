import SwiftUI

struct InputChrome: ViewModifier {
    @Environment(\.formhausTokens) private var tokens
    @State private var hovered = false
    let focused: Bool
    let invalid: Bool
    let disabled: Bool
    let padded: Bool

    init(focused: Bool, invalid: Bool, disabled: Bool, padded: Bool = true) {
        self.focused = focused
        self.invalid = invalid
        self.disabled = disabled
        self.padded = padded
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: tokens.radii.control, style: .continuous)
        content
            .formhausText(.body)
            .padding(.horizontal, padded ? tokens.spacing.s6 : 0)
            .padding(.vertical, padded ? tokens.spacing.s4 : 0)
            .frame(maxWidth: .infinity, minHeight: tokens.controls.height, alignment: .leading)
            .background(shape.fill(disabled ? tokens.colors.backgroundDisabled : tokens.colors.background))
            .overlay(shape.strokeBorder(borderColor, lineWidth: 1))
            .overlay(FocusRing(visible: focused, radius: tokens.radii.control))
            .contentShape(shape)
            .onHover { hovered = $0 }
            .animation(tokens.quick, value: focused)
            .animation(tokens.quick, value: hovered)
    }

    private var borderColor: Color {
        if focused { return tokens.colors.focus }
        if invalid { return tokens.colors.error }
        return hovered && !disabled ? tokens.colors.borderHover : tokens.colors.border
    }
}

public struct FocusRing: View {
    @Environment(\.formhausTokens) private var tokens
    let visible: Bool
    let radius: CGFloat
    let offset: CGFloat

    public init(visible: Bool, radius: CGFloat, offset: CGFloat = 1) {
        self.visible = visible
        self.radius = radius
        self.offset = offset
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: radius + offset + 1, style: .continuous)
            .strokeBorder(tokens.colors.focus, lineWidth: 2)
            .padding(-(offset + 2))
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    public func inputChrome(focused: Bool, invalid: Bool, disabled: Bool, padded: Bool = true) -> some View {
        modifier(InputChrome(focused: focused, invalid: invalid, disabled: disabled, padded: padded))
    }
}

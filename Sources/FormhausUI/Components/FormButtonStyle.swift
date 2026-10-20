@_spi(Renderer) import FormhausCore
import SwiftUI

public enum FormButtonVariant: String, Sendable {
    case primary
    case secondary
    case text
    case danger

    init(_ action: FormAction?, fallback: FormButtonVariant) {
        self = action?.variant.flatMap(FormButtonVariant.init(rawValue:)) ?? fallback
    }
}

public struct FormButtonStyle: ButtonStyle {
    let variant: FormButtonVariant
    let busy: Bool
    let compact: Bool

    public init(_ variant: FormButtonVariant, busy: Bool = false, compact: Bool = false) {
        self.variant = variant
        self.busy = busy
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        FormButtonBody(configuration: configuration, variant: variant, busy: busy, compact: compact)
    }
}

private struct FormButtonBody: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.isEnabled) private var enabled
    @State private var hovered = false
    let configuration: ButtonStyleConfiguration
    let variant: FormButtonVariant
    let busy: Bool
    let compact: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: tokens.radii.control, style: .continuous)
        configuration.label
            .formhausText(variant == .text || compact ? .textButton : .button, colored: false)
            .lineLimit(1)
            .animation(tokens.quick) { $0.foregroundStyle(foreground).opacity(busy ? 0 : 1) }
            .overlay {
                if busy {
                    ProgressView().controlSize(.small).tint(foreground).transition(.opacity.animation(tokens.quick))
                }
            }
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: compact ? tokens.controls.hitTarget : tokens.controls.height)
            .surface(shape, fill: fill, border: border, motion: tokens.quick)
            .contentShape(shape)
            .opacity(enabled || variant == .primary ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && !tokens.reduceMotion ? 0.98 : 1)
            .onHover { hovered = $0 }
    }

    private var horizontalPadding: CGFloat {
        if variant == .text || (variant == .danger && compact) { return tokens.spacing.s4 }
        return compact ? tokens.spacing.s7 : tokens.spacing.s9
    }

    private var active: Bool { (hovered || configuration.isPressed) && enabled }

    private var foreground: Color {
        switch variant {
        case .primary: enabled || busy ? tokens.colors.onPrimary : tokens.colors.primaryOnSoft
        case .secondary: tokens.colors.text
        case .text: active ? tokens.colors.text : tokens.colors.textMuted
        case .danger: active ? tokens.colors.errorHover : tokens.colors.error
        }
    }

    private var fill: Color {
        switch variant {
        case .primary: enabled || busy ? (active ? tokens.colors.primaryHover : tokens.colors.primary) : tokens.colors.primaryDisabled
        case .secondary: active ? tokens.colors.backgroundHover : tokens.colors.background
        case .text: active ? tokens.colors.backgroundHover : .clear
        case .danger: active ? tokens.colors.errorSoft : .clear
        }
    }

    private var border: Color {
        switch variant {
        case .primary, .text: .clear
        case .secondary: active ? tokens.colors.borderHover : tokens.colors.secondaryBorder
        case .danger: compact ? .clear : tokens.colors.error
        }
    }
}

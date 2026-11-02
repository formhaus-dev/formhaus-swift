import SwiftUI

public enum IndicatorShape: Sendable {
    case radio
    case checkbox
}

public struct ChoiceIndicator: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.formhausReadOnly) private var readOnly
    let shape: IndicatorShape
    let selected: Bool
    let invalid: Bool

    public init(_ shape: IndicatorShape, selected: Bool, invalid: Bool = false) {
        self.shape = shape
        self.selected = selected
        self.invalid = invalid
    }

    public var body: some View {
        let size = tokens.controls.indicator
        ZStack {
            if shape == .radio {
                Color.clear.surface(
                    Circle(), fill: empty, border: stroke, lineWidth: 2, motion: tokens.quick)
                Circle().fill(tokens.colors.primary).frame(width: size * 4 / 9, height: size * 4 / 9)
                    .animation(tokens.quick) { $0.opacity(selected ? 1 : 0) }
            } else {
                Color.clear.surface(
                    RoundedRectangle(cornerRadius: tokens.radii.indicator, style: .continuous),
                    fill: selected ? tokens.colors.primary : empty, border: stroke, lineWidth: 1.5,
                    motion: tokens.quick)
                tokens.colors.onPrimary
                    .mask { Image(systemName: "checkmark").font(.system(size: size * 0.62, weight: .bold)) }
                    .animation(tokens.quick) { $0.opacity(selected ? 1 : 0) }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var empty: Color {
        readOnly && !selected ? tokens.colors.backgroundDisabled : tokens.colors.background
    }

    private var stroke: Color {
        if selected { return tokens.colors.primary }
        if invalid { return tokens.colors.error }
        return readOnly ? tokens.colors.inputBorder : tokens.colors.control
    }
}

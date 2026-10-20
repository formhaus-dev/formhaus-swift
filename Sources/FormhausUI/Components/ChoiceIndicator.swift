import SwiftUI

public enum IndicatorShape: Sendable {
    case radio
    case checkbox
}

public struct ChoiceIndicator: View {
    @Environment(\.formhausTokens) private var tokens
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
                    Circle(), fill: tokens.colors.background, border: stroke, lineWidth: 2, motion: tokens.quick)
                Circle().fill(tokens.colors.primary).frame(width: size * 4 / 9, height: size * 4 / 9)
                    .animation(tokens.quick) { $0.opacity(selected ? 1 : 0) }
            } else {
                Color.clear.surface(
                    RoundedRectangle(cornerRadius: tokens.radii.indicator, style: .continuous),
                    fill: selected ? tokens.colors.primary : tokens.colors.background, border: stroke, lineWidth: 1.5,
                    motion: tokens.quick)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.62, weight: .bold))
                    .foregroundStyle(tokens.colors.onPrimary)
                    .animation(tokens.quick) { $0.opacity(selected ? 1 : 0) }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var stroke: Color {
        if selected { return tokens.colors.primary }
        return invalid ? tokens.colors.error : tokens.colors.control
    }
}

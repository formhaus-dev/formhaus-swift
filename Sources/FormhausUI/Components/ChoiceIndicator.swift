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
                IndicatorFace(shape: Circle(), fill: tokens.colors.background, stroke: stroke, width: 2)
            } else {
                IndicatorFace(
                    shape: RoundedRectangle(cornerRadius: tokens.radii.indicator, style: .continuous),
                    fill: selected ? tokens.colors.primary : tokens.colors.background, stroke: stroke, width: 1.5)
            }
            if selected, shape == .radio {
                Circle().fill(tokens.colors.primary).frame(width: size * 4 / 9, height: size * 4 / 9)
            }
            if selected, shape == .checkbox {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.62, weight: .bold))
                    .foregroundStyle(tokens.colors.onPrimary)
            }
        }
        .frame(width: size, height: size)
        .animation(tokens.quick, value: selected)
        .accessibilityHidden(true)
    }

    private var stroke: Color {
        if selected { return tokens.colors.primary }
        return invalid ? tokens.colors.error : tokens.colors.control
    }
}

private struct IndicatorFace<Outline: InsettableShape>: View {
    let shape: Outline
    let fill: Color
    let stroke: Color
    let width: CGFloat

    var body: some View {
        shape.fill(fill).overlay(shape.strokeBorder(stroke, lineWidth: width))
    }
}

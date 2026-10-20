import FormhausUI
import SwiftUI

struct KilnScaleField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        let scale = ScalePoints(context)
        let points = scale.points
        KilnFieldFrame(context: context) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(points, id: \.self) { point in
                        Button {
                            context.commit(.number(Double(point)))
                        } label: {
                            Text(verbatim: String(point))
                                .font(KilnType.body.weight(.semibold).monospacedDigit())
                                .foregroundStyle(current == point ? tokens.colors.onPrimary : tokens.colors.text)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Capsule().fill(current == point ? tokens.colors.primary : tokens.colors.backgroundDisabled))
                                .overlay(Capsule().strokeBorder(context.isInvalid ? tokens.colors.error : .clear, lineWidth: 1.5))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: String(point)))
                        .accessibilityAddTraits(current == point ? .isSelected : [])
                    }
                }
                HStack {
                    Text(verbatim: scale.anchor(for: scale.low) ?? "")
                    Spacer()
                    Text(verbatim: scale.anchor(for: scale.high) ?? "")
                }
                .font(KilnType.note)
                .foregroundStyle(tokens.colors.textMuted)
                .accessibilityHidden(true)
            }
            .formhausFocus(context, $focused)
            .sensoryFeedback(.selection, trigger: current)
            .animation(tokens.quick, value: current)
        }
    }

    private var current: Int? { ScalePoints(context).selected(context.value) }
}

struct KilnRatingField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        let scale = ScalePoints(context)
        let points = scale.points
        let current = scale.selected(context.value) ?? 0
        KilnFieldFrame(context: context) {
            HStack(spacing: 4) {
                ForEach(points, id: \.self) { point in
                    Button {
                        context.commit(.number(Double(point)))
                    } label: {
                        Image(systemName: point <= current ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundStyle(point <= current ? tokens.colors.primary : tokens.colors.control)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, -8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: context.accessibilityName))
            .accessibilityValue(current > 0 ? String(current) : "")
            .accessibilityAdjustableAction { direction in
                let next = current + (direction == .increment ? 1 : -1)
                context.setValue(.number(Double(scale.clamped(next))))
            }
            .formhausFocus(context, $focused)
            .sensoryFeedback(.selection, trigger: current)
        }
    }
}

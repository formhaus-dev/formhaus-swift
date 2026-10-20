import SwiftUI

struct SystemScale: View {
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        let scale = ScalePoints(context)
        let current = scale.selected(context.value)
        SystemBlock(context: context) {
            VStack(spacing: 8) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 56), spacing: 6)], spacing: 6) {
                    ForEach(scale.points, id: \.self) { point in
                        Button {
                            context.commit(.number(Double(point)))
                        } label: {
                            SystemScaleDot(point: point, selected: current == point)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if scale.anchors.contains(where: { $0 != nil }) {
                    HStack(alignment: .top) {
                        Text(verbatim: scale.anchors[0] ?? "")
                        Spacer(minLength: 12)
                        Text(verbatim: scale.anchors[2] ?? "").multilineTextAlignment(.trailing)
                    }
                    .font(.footnote)
                    .systemSecondaryText()
                    .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: context.accessibilityName))
            .accessibilityValue(spoken(scale, current))
            .accessibilityHint(Text(verbatim: context.helperText ?? ""))
            .accessibilityAdjustableAction { direction in step(scale, current, direction) }
            .focusable()
            .formhausFocus(context, $focused)
            .sensoryFeedback(.selection, trigger: current)
        }
    }

    private func spoken(_ scale: ScalePoints, _ current: Int?) -> String {
        guard let current else { return "" }
        return [String(current), scale.anchor(for: current)].compactMap(\.self).joined(separator: ", ")
    }

    private func step(_ scale: ScalePoints, _ current: Int?, _ direction: AccessibilityAdjustmentDirection) {
        let start = current ?? (direction == .increment ? scale.low - 1 : scale.high + 1)
        context.setValue(.number(Double(scale.clamped(start + (direction == .increment ? 1 : -1)))))
    }
}

private struct SystemScaleDot: View {
    let point: Int
    let selected: Bool

    var body: some View {
        Text(verbatim: String(point))
            .font(.body.monospacedDigit().weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(minWidth: 44, minHeight: 44)
            .background {
                if selected {
                    Circle().fill(.tint)
                } else {
                    Circle().strokeBorder(systemSecondary, lineWidth: 1)
                }
            }
            .contentShape(Circle())
    }
}

struct SystemRating: View {
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        let scale = ScalePoints(context)
        let current = scale.selected(context.value) ?? 0
        SystemBlock(context: context) {
            HStack(spacing: 0) {
                ForEach(scale.points, id: \.self) { point in
                    Button {
                        context.commit(.number(Double(point)))
                    } label: {
                        Image(systemName: point <= current ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(point <= current ? AnyShapeStyle(.tint) : AnyShapeStyle(systemSecondary))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, -8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: context.accessibilityName))
            .accessibilityValue(
                current > 0 ? [String(current), scale.anchor(for: current)].compactMap(\.self).joined(separator: ", ") : ""
            )
            .accessibilityAdjustableAction { direction in
                context.setValue(.number(Double(scale.clamped(direction == .increment ? current + 1 : current - 1))))
            }
            .focusable()
            .formhausFocus(context, $focused)
            .sensoryFeedback(.selection, trigger: current)
        }
    }
}

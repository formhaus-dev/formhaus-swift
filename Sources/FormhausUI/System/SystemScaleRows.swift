import SwiftUI

struct SystemScale: View {
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        let scale = ScalePoints(context)
        SystemBlock(context: context) {
            VStack(spacing: 6) {
                if scale.points.count > 7 {
                    picker(scale).pickerStyle(.menu).labelsHidden()
                } else {
                    picker(scale).pickerStyle(.segmented).labelsHidden()
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(context.accessibilityName)
                        .accessibilityValue(spoken(scale))
                        .accessibilityHint(context.helperText ?? "")
                        .accessibilityAdjustableAction { direction in step(scale, direction) }
                }
                if scale.anchors.contains(where: { $0 != nil }) {
                    HStack(alignment: .top) {
                        Text(scale.anchors[0] ?? "")
                        Spacer(minLength: 12)
                        Text(scale.anchors[2] ?? "").multilineTextAlignment(.trailing)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 4)
            .sensoryFeedback(.selection, trigger: scale.selected(context.value))
        }
    }

    private func picker(_ scale: ScalePoints) -> some View {
        Picker(selection: selection(scale)) {
            ForEach(scale.points, id: \.self) { point in
                Text(String(point)).monospacedDigit().tag(Optional(point)).accessibilityHint(scale.anchor(for: point) ?? "")
            }
        } label: {
            Text(context.accessibilityName)
        }
        .formhausFocus(context, $focused)
    }

    private func spoken(_ scale: ScalePoints) -> String {
        guard let point = scale.selected(context.value) else { return "" }
        return [String(point), scale.anchor(for: point)].compactMap(\.self).joined(separator: ", ")
    }

    private func step(_ scale: ScalePoints, _ direction: AccessibilityAdjustmentDirection) {
        let current = scale.selected(context.value) ?? (direction == .increment ? scale.low - 1 : scale.high + 1)
        let next = current + (direction == .increment ? 1 : -1)
        if scale.points.contains(next) { context.setValue(.number(Double(next))) }
    }

    private func selection(_ scale: ScalePoints) -> Binding<Int?> {
        Binding(get: { scale.selected(context.value) }, set: { point in point.map { context.commit(.number(Double($0))) } })
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
                            .foregroundStyle(point <= current ? AnyShapeStyle(.tint) : AnyShapeStyle(context.isInvalid ? .red : .secondary))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, -8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(context.accessibilityName)
            .accessibilityValue(
                current > 0 ? [String(current), scale.anchor(for: current)].compactMap(\.self).joined(separator: ", ") : ""
            )
            .accessibilityAdjustableAction { direction in
                let next = direction == .increment ? current + 1 : current - 1
                if scale.points.contains(next) { context.setValue(.number(Double(next))) }
            }
            .focusable()
            .formhausFocus(context, $focused)
            .sensoryFeedback(.selection, trigger: current)
        }
    }
}

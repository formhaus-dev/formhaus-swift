import FormhausCore
import FormhausUI
import SwiftUI

struct KilnChoiceField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        KilnFieldFrame(context: context) {
            Group {
                if context.options.contains(where: { $0.image?.isEmpty == false }) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) { options(pictures: true) }
                } else {
                    KilnFlow(spacing: 8) { options(pictures: false) }
                }
            }
            .formhausFocus(context, $focused)
            .sensoryFeedback(.selection, trigger: selection.values)
        }
    }

    private func options(pictures: Bool) -> some View {
        ForEach(Array(context.options.enumerated()), id: \.offset) { _, option in
            let value = option.value ?? ""
            let isOn = selection.isSelected(value)
            Button {
                selection.choose(value)
            } label: {
                if pictures {
                    KilnPictureCard(option: option, selected: isOn)
                } else {
                    KilnChip(label: option.label ?? value, selected: isOn, invalid: context.isInvalid)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: option.label ?? value))
            .accessibilityAddTraits(isOn ? [.isSelected] : [])
        }
    }

    private var selection: ChoiceSelection { ChoiceSelection(context: context) }
}

struct KilnChip: View {
    @Environment(\.formhausTokens) private var tokens
    let label: String
    let selected: Bool
    let invalid: Bool

    var body: some View {
        HStack(spacing: 6) {
            if selected { Image(systemName: "checkmark").font(KilnType.note.weight(.bold)) }
            Text(verbatim: label).font(KilnType.body.weight(.medium))
        }
        .foregroundStyle(selected ? tokens.colors.onPrimary : tokens.colors.text)
        .padding(.horizontal, 18)
        .frame(minHeight: 44)
        .background(Capsule().fill(selected ? tokens.colors.primary : tokens.colors.backgroundDisabled))
        .overlay(Capsule().strokeBorder(border, lineWidth: invalid && !selected ? 1.5 : 1))
        .contentShape(Capsule())
        .animation(tokens.quick, value: selected)
    }

    private var border: Color {
        if selected { return .clear }
        return invalid ? tokens.colors.error : tokens.colors.secondaryBorder
    }
}

private struct KilnPictureCard: View {
    @Environment(\.formhausTokens) private var tokens
    let option: FieldOption
    let selected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            Color.clear
                .overlay { FormhausOptionImage(option: option) }
                .background(tokens.colors.border)
                .saturation(0)
                .colorMultiply(Color(kiln: 0xF2D3BD))
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(verbatim: option.label ?? option.value ?? "")
                .font(KilnType.heading)
                .foregroundStyle(tokens.colors.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .padding(8)
        .padding(.bottom, 4)
        .background(shape.fill(selected ? tokens.colors.primarySoft : tokens.colors.backgroundDisabled))
        .overlay(shape.strokeBorder(selected ? tokens.colors.primary : .clear, lineWidth: 2))
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark")
                    .font(KilnType.note.weight(.heavy))
                    .foregroundStyle(tokens.colors.onPrimary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(tokens.colors.primary))
                    .padding(16)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .contentShape(shape)
        .animation(tokens.quick, value: selected)
    }
}

struct KilnFlow: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let frames = place(width, subviews)
        return CGSize(width: width.isFinite ? width : frames.map(\.maxX).max() ?? 0, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        for (index, frame) in place(bounds.width, subviews).enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .init(frame.size))
        }
    }

    private func place(_ width: CGFloat, _ subviews: Subviews) -> [CGRect] {
        var frames: [CGRect] = []
        var origin = CGPoint.zero
        var line: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            size.width = min(size.width, width)
            if origin.x > 0, origin.x + size.width > width {
                origin = CGPoint(x: 0, y: origin.y + line + spacing)
                line = 0
            }
            frames.append(CGRect(origin: origin, size: size))
            origin.x += size.width + spacing
            line = max(line, size.height)
        }
        return frames
    }
}

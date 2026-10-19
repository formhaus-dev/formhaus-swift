import FormhausUI
import SwiftUI

struct KilnStepHeader: View {
    @Environment(\.formhausTokens) private var tokens
    let context: ProgressContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(1...max(1, context.total), id: \.self) { step in
                    Capsule()
                        .fill(step <= context.current ? tokens.colors.primary : tokens.colors.border)
                        .frame(height: 6)
                }
            }
            .accessibilityHidden(true)
            Text(context.counterLabel.uppercased())
                .font(KilnType.eyebrow)
                .tracking(1.2)
                .foregroundStyle(tokens.colors.primary)
                .padding(.top, 6)
            if let title = context.stepTitle {
                Text(title).font(KilnType.title).foregroundStyle(tokens.colors.text).accessibilityAddTraits(.isHeader)
            }
            if let description = context.stepDescription {
                Text(description).font(KilnType.body).foregroundStyle(tokens.colors.textMuted)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KilnSection: View {
    @Environment(\.formhausTokens) private var tokens
    let context: SectionContext

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.title).font(KilnType.heading).foregroundStyle(tokens.colors.text).accessibilityAddTraits(.isHeader)
                if let description = context.description {
                    Text(description).font(KilnType.note).foregroundStyle(tokens.colors.textMuted)
                }
            }
            context.content
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(tokens.colors.backgroundDisabled.opacity(0.6)))
        .accessibilityElement(children: .contain)
    }
}

struct KilnActions: View {
    @Environment(\.formhausTokens) private var tokens
    let context: ActionsContext

    var body: some View {
        HStack(spacing: 12) {
            if context.state.showBack {
                Button(action: context.back) {
                    Image(systemName: "arrow.left").font(.body.weight(.semibold))
                        .frame(width: 52, height: 52)
                        .background(Circle().strokeBorder(tokens.colors.border, lineWidth: 1.5))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(tokens.colors.text)
                .accessibilityLabel(context.state.backLabel)
                .disabled(context.busy)
            }
            if context.state.showPrimary {
                Button(action: context.performPrimaryAction) {
                    HStack(spacing: 10) {
                        Text(context.state.primaryLabel)
                        if context.busy { ProgressView().tint(tokens.colors.onPrimary) } else { Image(systemName: "arrow.right") }
                    }
                    .font(KilnType.body.weight(.semibold))
                    .foregroundStyle(tokens.colors.onPrimary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(tokens.colors.primary))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(context.busy || context.state.primaryDisabled)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.top, 8)
    }
}

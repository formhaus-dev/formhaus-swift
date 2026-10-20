@_spi(Renderer) import FormhausCore
import SwiftUI

public struct FormErrorSummary: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.displayScale) private var displayScale
    let model: FormModel

    public init(model: FormModel) {
        self.model = model
    }

    public var body: some View {
        let groups = model.errorGroups
        if !groups.isEmpty {
            let shape = RoundedRectangle(cornerRadius: tokens.radii.control, style: .continuous)
            let title = model.text(forLabel: "errorSummary")
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: title).formhausText(.label).accessibilityAddTraits(.isHeader).padding(.bottom, tokens.spacing.s1)
                    .formhausSummaryFocus(model)
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    if groups.count > 1 {
                        Text(verbatim: group.title).formhausText(.helper).accessibilityAddTraits(.isHeader)
                            .padding(.top, index > 0 ? tokens.spacing.s5 : tokens.spacing.s3)
                    }
                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { row, entry in
                        if row > 0 { tokens.colors.border.frame(height: 1 / displayScale).accessibilityHidden(true) }
                        entryButton(entry)
                    }
                }
            }
            .padding(.vertical, tokens.spacing.s5)
            .padding(.horizontal, tokens.spacing.s6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(shape.strokeBorder(tokens.colors.error, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .id(ScrollAnchor.summary(model))
            .measured("summary")
            .onAppear { announce(title) }
        }
    }

    private func entryButton(_ entry: ErrorEntry) -> some View {
        Button {
            model.focus(field: entry.key)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: tokens.spacing.s3) {
                Text(verbatim: entry.text).fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: tokens.typography.small, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .formhausText(.body, colored: false)
            .foregroundStyle(tokens.colors.error)
            .padding(.vertical, tokens.spacing.s3)
            .frame(minHeight: tokens.controls.hitTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

public struct FormTopLevelErrors: View {
    @Environment(\.formhausTokens) private var tokens
    let model: FormModel

    public init(model: FormModel) {
        self.model = model
    }

    public var body: some View {
        let errors = model.topLevelErrors + (model.actionError.map { [$0] } ?? [])
        if !errors.isEmpty {
            VStack(alignment: .leading, spacing: tokens.spacing.s1) {
                ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                    FieldError(text: error)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@_spi(Renderer) import FormhausCore
import SwiftUI

public struct FormErrorSummary: View {
    @Environment(\.formhausTokens) private var tokens
    let model: FormModel

    public init(model: FormModel) {
        self.model = model
    }

    public var body: some View {
        let entries = model.errorEntries
        if !entries.isEmpty {
            let shape = RoundedRectangle(cornerRadius: tokens.radii.control, style: .continuous)
            let title = model.label("errorSummary")
            VStack(alignment: .leading, spacing: tokens.spacing.s1) {
                Text(title).formhausText(.label).accessibilityAddTraits(.isHeader)
                ForEach(entries) { entry in
                    Button {
                        model.show(entry.key)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: tokens.spacing.s3) {
                            Text(verbatim: "•").accessibilityHidden(true)
                            Text(verbatim: "\(entry.label): \(entry.message)").underline().fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                        .formhausText(.body, colored: false)
                        .foregroundStyle(tokens.colors.error)
                        .frame(minHeight: tokens.controls.hitTarget * 0.6, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, tokens.spacing.s5)
            .padding(.horizontal, tokens.spacing.s6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(shape.strokeBorder(tokens.colors.error, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .onAppear { announce(title) }
        }
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

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
            let title = model.text(forLabel: "errorSummary")
            VStack(alignment: .leading, spacing: tokens.spacing.s1) {
                Text(title).formhausText(.label).accessibilityAddTraits(.isHeader)
                ForEach(entries) { entry in
                    Button {
                        model.focus(field: entry.key)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: tokens.spacing.s3) {
                            Text(verbatim: "•").accessibilityHidden(true)
                            Text(verbatim: summaryLine(entry.label, entry.message)).fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.system(size: tokens.typography.small, weight: .semibold))
                                .accessibilityHidden(true)
                        }
                        .formhausText(.body, colored: false)
                        .foregroundStyle(tokens.colors.error)
                        .frame(minHeight: tokens.controls.hitTarget, alignment: .leading)
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

private let closingPunctuation: Set<Character> = ["?", "!", ":", ".", "\u{FF1F}", "\u{FF01}", "\u{FF1A}", "\u{FF0E}", "\u{3002}"]

func summaryLine(_ label: String, _ message: String) -> String {
    guard let last = label.last, closingPunctuation.contains(last) else { return "\(label): \(message)" }
    return "\(label) \(message)"
}

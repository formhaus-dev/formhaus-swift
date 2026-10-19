import SwiftUI

public enum FieldShellVariant: Sendable {
    case standard
    case inline
    case row
    case group
}

public struct FieldShell<Content: View>: View {
    @Environment(\.formhausTokens) private var tokens
    let context: FieldContext
    let variant: FieldShellVariant
    let content: Content

    public init(_ context: FieldContext, variant: FieldShellVariant = .standard, @ViewBuilder content: () -> Content) {
        self.context = context
        self.variant = variant
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacing.s3) {
            if !isInline, !context.label.isEmpty {
                FieldLabel(text: context.label, required: context.isRequired)
                    .accessibilityAddTraits(variant == .group ? .isHeader : [])
            }
            if !isInline, let helper = context.helperText {
                Text(helper).formhausText(.helper).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -tokens.spacing.s1)
            }
            content
            if isInline, let helper = context.helperText {
                Text(helper).formhausText(.helper).fixedSize(horizontal: false, vertical: true).padding(.leading, inset)
                    .padding(.top, variant == .row ? -tokens.spacing.s3 : -tokens.spacing.s1)
            }
            if let error = context.error, !error.isEmpty {
                FieldError(text: error).padding(.leading, inset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .id(context.key)
    }

    private var isInline: Bool { variant == .inline || variant == .row }

    private var inset: CGFloat { variant == .inline ? tokens.controls.indicator + tokens.spacing.s5 : 0 }
}

public struct FieldLabel: View {
    @Environment(\.formhausTokens) private var tokens
    let text: String
    let required: Bool

    public init(text: String, required: Bool) {
        self.text = text
        self.required = required
    }

    public var body: some View {
        (Text(text) + Text(required ? " *" : "").foregroundStyle(tokens.colors.error))
            .formhausText(.label)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(text)
    }
}

public struct FieldError: View {
    let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .formhausText(.error)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear { announce(text) }
            .onChange(of: text) { _, message in announce(message) }
    }
}

@MainActor
func announce(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
}

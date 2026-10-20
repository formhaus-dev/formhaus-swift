@_spi(Renderer) import FormhausCore
import SwiftUI

public struct TextAreaField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        FieldShell(context) {
            HStack(alignment: .top, spacing: tokens.spacing.s3) {
                TextField(text: context.textBinding, prompt: Text(verbatim: ""), axis: .vertical) {
                    Text(verbatim: context.accessibilityName)
                }
                .placeholder(context.field.placeholder, visible: context.text.isEmpty)
                .textFieldStyle(.plain)
                .lineLimit(rows...)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
                .accessibilityHint(Text(verbatim: context.helperText ?? ""))
                LoadingIndicator(visible: context.loading)
            }
            .inputChrome(focused: focused, invalid: context.isInvalid, disabled: context.isLocked)
            .disabled(context.isLocked)
            .formhausFocus(context, $focused)
        }
    }

    private var rows: Int {
        clampedInt(context.field.rows?.numberValue, 1...40) ?? 3
    }

    private var minHeight: CGFloat {
        max(tokens.controls.textareaHeight - 2 * tokens.spacing.s4 - 2, CGFloat(rows) * tokens.typography.body * 1.5)
    }
}

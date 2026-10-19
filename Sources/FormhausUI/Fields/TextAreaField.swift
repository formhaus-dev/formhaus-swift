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
            TextField(text: context.textBinding, prompt: Text(verbatim: ""), axis: .vertical) { Text(context.label) }
                .placeholder(context.field.placeholder, visible: context.text.isEmpty)
                .textFieldStyle(.plain)
                .lineLimit(rows...)
                .frame(minHeight: minHeight, alignment: .topLeading)
                .accessibilityHint(context.helperText ?? "")
                .inputChrome(focused: focused, invalid: context.isInvalid, disabled: context.isLocked)
                .disabled(context.isLocked)
                .fieldFocus(context, $focused)
        }
    }

    private var rows: Int {
        clampedInt(context.field.rows?.numberValue, 1...40) ?? 3
    }

    private var minHeight: CGFloat {
        max(tokens.controls.textareaHeight - 2 * tokens.spacing.s4 - 2, CGFloat(rows) * tokens.typography.body * 1.5)
    }
}

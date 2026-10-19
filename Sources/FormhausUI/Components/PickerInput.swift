import FormhausCore
import SwiftUI

struct PickerInput<Label: View>: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let context: FieldContext
    let active: Bool
    let clearable: Bool
    let cleared: JSONValue
    let label: Label
    let open: () -> Void

    var body: some View {
        FieldShell(context) {
            HStack(spacing: tokens.spacing.s3) {
                Button(action: open) { label }
                    .buttonStyle(.plain)
                FieldAccessories(context: context, clearable: clearable) { context.setValue(cleared) }
            }
            .inputChrome(focused: focused || active, invalid: context.isInvalid, disabled: context.isLocked)
            .disabled(context.isLocked)
            .formhausFocus(context, $focused)
            .accessibilityHint(context.helperText ?? "")
        }
    }
}

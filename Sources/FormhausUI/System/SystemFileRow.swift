import SwiftUI

struct SystemFileRow: View {
    @FocusState private var focused: Bool
    @State private var picking = false
    let context: FieldContext

    var body: some View {
        SystemRow(context: context) {
            Button {
                picking = true
            } label: {
                HStack {
                    SystemRowLabel(context: context)
                    Spacer(minLength: 12)
                    Text(context.fileName ?? context.field.placeholder ?? context.text(forLabel: "chooseFile"))
                        .systemSecondaryText()
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(context.accessibilityName)
            .accessibilityValue(context.fileName ?? context.text(forLabel: "chooseFile"))
            .accessibilityHint(context.helperText ?? "")
            .formhausFocus(context, $focused)
            .swipeActions {
                if context.fileName != nil, !context.isRequired {
                    Button(context.text(forLabel: "clear"), role: .destructive) { context.replaceFile(with: nil) }
                }
            }
        }
        .filePicker(context, isPresented: $picking)
    }
}

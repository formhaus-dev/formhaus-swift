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
                    Text(verbatim: context.fileName ?? context.reference ?? context.placeholder ?? context.text(forLabel: "chooseFile"))
                        .systemSecondaryText()
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: context.accessibilityName))
            .accessibilityValue(context.fileValueText)
            .accessibilityHint(Text(verbatim: context.helperText ?? ""))
            .formhausFocus(context, $focused)
            .swipeActions {
                if !context.text.isEmpty, !context.isRequired {
                    Button(context.text(forLabel: "clear"), role: .destructive) { context.replaceFile(with: nil) }
                }
            }
        }
        .filePicker(context, isPresented: $picking)
    }
}

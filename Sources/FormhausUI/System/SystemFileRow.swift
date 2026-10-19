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
                    Text(context.label).foregroundStyle(Color.primary)
                    Spacer(minLength: 12)
                    Text(context.fileName ?? context.field.placeholder ?? context.text(forLabel: "chooseFile"))
                        .foregroundStyle(context.fileName == nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(minHeight: 44)
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

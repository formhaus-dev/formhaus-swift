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
            if context.field.isFileList {
                ForEach(context.pickedFiles, id: \.url) { file in
                    SystemFileItem(context: context, index: file.index, name: file.url.lastPathComponent)
                }
            }
        }
        .filePicker(context, isPresented: $picking)
    }
}

private struct SystemFileItem: View {
    @FocusState private var focused: Bool
    let context: FieldContext
    let index: Int
    let name: String

    var body: some View {
        HStack {
            Label {
                Text(verbatim: name).lineLimit(1).truncationMode(.middle)
            } icon: {
                Image(systemName: "doc")
            }
            Spacer(minLength: 12)
            Button(role: .destructive) {
                context.removeFile(at: index)
            } label: {
                Text(verbatim: context.removeFileLabel).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(verbatim: context.removeFileName(name)))
            .focused($focused)
            .onFormhausFocus(context.removeFocus(index), model: context.model, disabled: context.isLocked) { focused = true }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
    }
}

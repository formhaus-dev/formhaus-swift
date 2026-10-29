import SwiftUI

struct SystemFileRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var focused: Bool
    @State private var picking = false
    let context: FieldContext

    var body: some View {
        SystemRow(context: context) {
            Button {
                picking = true
            } label: {
                FileRowStack(spacing: nil) {
                    SystemRowLabel(context: context)
                    if !typeSize.isAccessibilitySize { Spacer(minLength: 12) }
                    Text(verbatim: context.fileName ?? context.reference ?? context.placeholder ?? context.text(forLabel: "chooseFile"))
                        .systemSecondaryText()
                        .accessibleLineLimit(1)
                        .truncationMode(.middle)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(context.isFileListFull)
            .accessibilityLabel(Text(verbatim: context.accessibilityName))
            .accessibilityValue(context.fileValueText)
            .accessibilityHint(Text(verbatim: context.pickerHint ?? ""))
            .formhausFocus(context, $focused)
            .swipeActions {
                if !context.text.isEmpty, !context.isRequired {
                    Button(context.text(forLabel: "clear"), role: .destructive) { context.replaceFile(with: nil) }
                }
            }
            if context.field.isFileList {
                ForEach(context.fileRows, id: \.index) { row in
                    SystemFileItem(context: context, index: row.index, name: row.name)
                }
                if let notice = context.state.notice {
                    Text(verbatim: notice).font(.footnote).systemSecondaryText().fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .filePicker(context, isPresented: $picking)
    }
}

private struct SystemFileItem: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var focused: Bool
    let context: FieldContext
    let index: Int
    let name: String

    var body: some View {
        FileRowStack(spacing: nil) {
            if typeSize.isAccessibilitySize {
                Text(verbatim: name).fileNameWrapping()
            } else {
                Label {
                    Text(verbatim: name).fileNameWrapping()
                } icon: {
                    Image(systemName: "doc")
                }
                Spacer(minLength: 12)
            }
            Button(role: .destructive) {
                context.removeFile(at: index)
            } label: {
                Text(verbatim: context.removeFileLabel).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .fileRemoveSizing()
            .accessibilityLabel(Text(verbatim: context.removeFileName(name)))
            .spokenFocus(context.removeFocus(index), model: context.model, disabled: context.isLocked, $focused)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
    }
}

import SwiftUI

struct FileList: View {
    let context: FieldContext

    var body: some View {
        ForEach(context.fileRows, id: \.index) { row in
            FileListRow(context: context, index: row.index, name: row.name)
        }
    }
}

private struct FileListRow: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var focused: Bool
    let context: FieldContext
    let index: Int
    let name: String

    var body: some View {
        HStack(spacing: tokens.spacing.s3) {
            Image(systemName: "doc").formhausText(.body, colored: false).foregroundStyle(tokens.colors.textMuted)
                .accessibilityHidden(true)
            Text(verbatim: name)
                .formhausText(.body)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: { context.removeFile(at: index) }, label: { Text(verbatim: context.removeFileLabel) })
                .buttonStyle(FormButtonStyle(.danger, compact: true))
                .disabled(context.isLocked)
                .accessibilityLabel(Text(verbatim: context.removeFileName(name)))
                .focused($focused)
                .onFormhausFocus(context.removeFocus(index), model: context.model, disabled: context.isLocked) { focused = true }
        }
        .padding(.leading, tokens.spacing.s4)
        .frame(minHeight: tokens.controls.hitTarget)
        .accessibilityElement(children: .contain)
    }
}

extension FieldContext {
    var fileRows: [FileRow] { model.fileRows(value) }

    var fileRoom: Int { model.fileRoom(field, value) }

    var isFileListFull: Bool { field.isFileList && fileRoom == 0 }

    var removeFileLabel: String { text(forLabel: "removeItem") }

    func removeFileName(_ name: String) -> String {
        text(forLabel: "removeItemNamed", ["label": .string(removeFileLabel), "item": .string(name)])
    }

    func removeFocus(_ index: Int) -> FieldState {
        model.field(model.removeFileKey(key, index))
    }

    func removeFile(at index: Int) {
        model.removeFile(at: index, forKey: key)
    }
}

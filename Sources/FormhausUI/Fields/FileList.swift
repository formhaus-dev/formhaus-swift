@_spi(Renderer) import FormhausCore
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
                .fileNameWrapping()
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: { context.removeFile(at: index) }, label: { Text(verbatim: context.removeFileLabel) })
                .buttonStyle(FormButtonStyle(.danger, compact: true))
                .disabled(context.isLocked)
                .accessibilityLabel(Text(verbatim: context.removeFileName(name)))
                .spokenFocus(context.removeFocus(index), model: context.model, disabled: context.isLocked, $focused)
        }
        .padding(.leading, tokens.spacing.s4)
        .frame(minHeight: tokens.controls.hitTarget)
        .accessibilityElement(children: .contain)
    }
}

private struct FileNameWrapping: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        content
            .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
            .truncationMode(.middle)
    }
}

extension View {
    func fileNameWrapping() -> some View {
        modifier(FileNameWrapping())
    }
}

extension FieldContext {
    var pickerHint: String? {
        let parts = [helperText, isFileListFull ? model.engine.fileLimit(field).message : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    var fileRows: [FileRow] { model.fileRows(value) }

    var fileRoom: Int { model.fileRoom(field, value) }

    var isFileListFull: Bool { field.isFileList && fileRoom == 0 }

    var removeFileLabel: String { text(forLabel: "removeItem") }

    func removeFileName(_ name: String) -> String {
        text(forLabel: "removeItemNamed", ["label": .string(removeFileLabel), "item": .string(isolatedFileName(name))])
    }

    func removeFocus(_ index: Int) -> FieldState {
        model.field(model.removeFileKey(key, index))
    }

    func removeFile(at index: Int) {
        model.removeFile(at: index, forKey: key)
    }
}

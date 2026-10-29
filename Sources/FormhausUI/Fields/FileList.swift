import PhotosUI
import SwiftUI

struct FileList: View {
    let context: FieldContext

    var body: some View {
        ForEach(context.pickedFiles, id: \.url) { file in
            FileListRow(context: context, index: file.index, name: file.url.lastPathComponent)
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
            Image(systemName: "doc").formhausText(.body, colored: false).foregroundStyle(tokens.colors.textMuted).accessibilityHidden(true)
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
    var pickedFiles: [(index: Int, url: URL)] { model.pickedFiles(value) }

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

extension View {
    @ViewBuilder
    func photoPicker(
        _ multiple: Bool, isPresented: Binding<Bool>, item: Binding<PhotosPickerItem?>, items: Binding<[PhotosPickerItem]>,
        pick: @escaping ([PhotosPickerItem]) -> Void
    ) -> some View {
        if multiple {
            photosPicker(isPresented: isPresented, selection: items, matching: .images)
                .onChange(of: items.wrappedValue) { _, picked in
                    if !picked.isEmpty { pick(picked) }
                }
        } else {
            photosPicker(isPresented: isPresented, selection: item, matching: .images)
                .onChange(of: item.wrappedValue) { _, picked in
                    if let picked { pick([picked]) }
                }
        }
    }
}

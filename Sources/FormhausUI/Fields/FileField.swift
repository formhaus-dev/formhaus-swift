import SwiftUI

public struct FileField: View {
    @Environment(\.formhausTokens) private var tokens
    @State private var picking = false
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        if context.field.isFileList {
            FieldShell(context) {
                VStack(alignment: .leading, spacing: tokens.spacing.s3) {
                    PickerControl(context: context, active: picking, clearable: false, cleared: .null, label: summary) { picking = true }
                    FileList(context: context)
                    if let notice = context.state.notice {
                        Text(verbatim: notice).formhausText(.helper).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .filePicker(context, isPresented: $picking)
        } else {
            PickerInput(context: context, active: picking, clearable: context.hasFile, cleared: .null, label: summary) {
                picking = true
            }
            .filePicker(context, isPresented: $picking)
        }
    }

    private var summary: some View {
        HStack(spacing: tokens.spacing.s3) {
            if context.reference == nil {
                Image(systemName: "paperclip").foregroundStyle(tokens.colors.textMuted)
            }
            Text(verbatim: context.fileName ?? context.reference ?? context.placeholder ?? context.text(forLabel: "chooseFile"))
                .formhausText(.body, colored: false)
                .foregroundStyle(summaryColor)
                .accessibleLineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: tokens.controls.hitTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: context.accessibilityName))
        .accessibilityValue(context.fileValueText)
        .accessibilityAddTraits(.isButton)
    }

    private var summaryColor: Color {
        if context.fileName != nil { return tokens.colors.text }
        return context.reference == nil ? tokens.colors.control : tokens.colors.textMuted
    }
}

extension FieldContext {
    var fileName: String? {
        field.isFileList ? nil : UploadStore.owned(text, by: ObjectIdentifier(model))?.lastPathComponent
    }

    var reference: String? {
        field.isFileList || text.isEmpty || fileName != nil || UploadStore.isMissing(text) ? nil : text
    }

    var hasFile: Bool { fileName != nil || reference != nil }

    var fileValueText: String {
        let count = field.isFileList ? fileRows.count : 0
        return count > 0
            ? text(forLabel: "fileCount", ["count": .number(Double(count))]) : fileName ?? reference ?? text(forLabel: "chooseFile")
    }

    func replaceFile(with url: URL?) {
        let previous = model.pickedFile(forKey: key)
        setValue(url.map { .string($0.absoluteString) } ?? .null)
        if let previous, model.pickedFile(forKey: key) != previous {
            UploadStore.discard(previous, owner: ObjectIdentifier(model))
        }
    }

    func receiveFiles(_ urls: [URL], overflow: Bool = false) {
        if field.isFileList {
            model.addFiles(urls, to: field, at: key, overflow: overflow)
        } else if let url = urls.first {
            replaceFile(with: url)
        }
    }
}

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

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
                .lineLimit(1)
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
        fileName ?? reference ?? text(forLabel: "chooseFile")
    }

    func replaceFile(with url: URL?) {
        let previous = model.pickedFile(forKey: key)
        setValue(url.map { .string($0.absoluteString) } ?? .null)
        if let previous, model.pickedFile(forKey: key) != previous {
            UploadStore.discard(previous, owner: ObjectIdentifier(model))
        }
    }

    func receiveFiles(_ urls: [URL]) {
        if field.isFileList {
            model.addFiles(urls, forKey: key)
        } else if let url = urls.first {
            replaceFile(with: url)
        }
    }
}

private struct FilePicker: ViewModifier {
    @State private var importing = false
    @State private var photo: PhotosPickerItem?
    @State private var photos: [PhotosPickerItem] = []
    @State private var choosingPhoto = false
    @Binding var isPresented: Bool
    let context: FieldContext

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, shown in
                guard shown else { return }
                isPresented = false
                if photosOnly { choosingPhoto = true } else { importing = true }
            }
            .fileImporter(
                isPresented: $importing, allowedContentTypes: types, allowsMultipleSelection: context.field.isFileList,
                onCompletion: imported
            )
            .photoPicker(context.field.isFileList, isPresented: $choosingPhoto, item: $photo, items: $photos) { items in
                Task { await store(items) }
            }
    }

    private var photosOnly: Bool {
        #if os(iOS)
            types.allSatisfy { $0.conforms(to: .image) }
        #else
            false
        #endif
    }

    private var types: [UTType] { acceptedTypes(context.field.accept?.stringValue) }

    private func imported(_ result: Result<[URL], any Error>) {
        guard case .success(let urls) = result else { return }
        let owner = ObjectIdentifier(context.model)
        Task {
            var copies: [URL] = []
            for url in urls { if let copy = await UploadStore.copy(url, owner: owner) { copies.append(copy) } }
            context.receiveFiles(copies)
        }
    }

    private func store(_ items: [PhotosPickerItem]) async {
        defer {
            photo = nil
            photos = []
        }
        var urls: [URL] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            if let url = await UploadStore.write(data, ext: ext, owner: ObjectIdentifier(context.model)) { urls.append(url) }
        }
        context.receiveFiles(urls)
    }
}

extension View {
    func filePicker(_ context: FieldContext, isPresented: Binding<Bool>) -> some View {
        modifier(FilePicker(isPresented: isPresented, context: context))
    }
}

func acceptedTypes(_ accept: String?) -> [UTType] {
    let entries = (accept ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
    let types = entries.compactMap { entry -> UTType? in
        if entry.hasPrefix(".") { return UTType(filenameExtension: String(entry.dropFirst())) }
        switch entry {
        case "image/*": return .image
        case "video/*": return .movie
        case "audio/*": return .audio
        case "text/*": return .text
        default: return UTType(mimeType: entry)
        }
    }
    return types.isEmpty ? [.item] : types
}

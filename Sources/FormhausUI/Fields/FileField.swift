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
        PickerInput(context: context, active: picking, clearable: !context.text.isEmpty, cleared: .null, label: summary) {
            picking = true
        }
        .filePicker(context, isPresented: $picking)
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
        UploadStore.owned(text, by: ObjectIdentifier(model))?.lastPathComponent
    }

    var reference: String? {
        text.isEmpty || fileName != nil ? nil : text
    }

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
}

private struct FilePicker: ViewModifier {
    @State private var importing = false
    @State private var photo: PhotosPickerItem?
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
            .fileImporter(isPresented: $importing, allowedContentTypes: types) { result in
                guard case .success(let url) = result else { return }
                let owner = ObjectIdentifier(context.model)
                Task { if let copy = await UploadStore.copy(url, owner: owner) { context.replaceFile(with: copy) } }
            }
            .photosPicker(isPresented: $choosingPhoto, selection: $photo, matching: .images)
            .onChange(of: photo) { _, item in
                guard let item else { return }
                Task { await store(item) }
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

    private func store(_ item: PhotosPickerItem) async {
        defer { photo = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
        guard let url = await UploadStore.write(data, ext: ext, owner: ObjectIdentifier(context.model)) else { return }
        context.replaceFile(with: url)
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

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

public struct FileField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    @State private var importing = false
    @State private var photo: PhotosPickerItem?
    @State private var choosingPhoto = false
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        FieldShell(context) {
            HStack(spacing: tokens.spacing.s3) {
                picker
                LoadingIndicator(visible: context.loading)
                if !context.text.isEmpty, !context.isLocked {
                    IconButton(systemName: "xmark.circle.fill", label: context.label("removeItem"), embedded: true) {
                        context.setValue(.null)
                    }
                }
            }
            .inputChrome(focused: focused, invalid: context.isInvalid, disabled: context.isLocked)
            .disabled(context.isLocked)
            .formhausFocus(context, $focused)
            .accessibilityHint(context.helperText ?? "")
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: types) { result in
            if case .success(let url) = result { context.setValue(.string(url.absoluteString)) }
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task { await store(item) }
        }
    }

    private var picker: some View {
        Button {
            if photosOnly { choosingPhoto = true } else { importing = true }
        } label: {
            summary
        }
        .buttonStyle(.plain)
        .photosPicker(isPresented: $choosingPhoto, selection: $photo, matching: .images)
    }

    private var photosOnly: Bool {
        #if os(iOS)
            types.allSatisfy { $0.conforms(to: .image) }
        #else
            false
        #endif
    }

    private var summary: some View {
        HStack(spacing: tokens.spacing.s3) {
            Image(systemName: "paperclip").foregroundStyle(tokens.colors.textMuted)
            Text(fileName ?? context.field.placeholder ?? "")
                .formhausText(.body, colored: false)
                .foregroundStyle(fileName == nil ? tokens.colors.control : tokens.colors.text)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(context.accessibilityName)
        .accessibilityValue(fileName ?? "")
        .accessibilityAddTraits(.isButton)
    }

    private var fileName: String? {
        guard !context.text.isEmpty else { return nil }
        return URL(string: context.text)?.lastPathComponent ?? context.text
    }

    private var types: [UTType] { acceptedTypes(context.field.accept?.stringValue) }

    private func store(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        guard (try? data.write(to: url)) != nil else { return }
        context.setValue(.string(url.absoluteString))
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

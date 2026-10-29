import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

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
            .photoPicker(
                context.field.isFileList ? context.fileRoom : nil, isPresented: $choosingPhoto, item: $photo, items: $photos, pick: pick)
    }

    private func pick(_ items: [PhotosPickerItem]) {
        Task { await store(items) }
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
        guard case .success(let picked) = result else { return }
        let owner = ObjectIdentifier(context.model)
        let urls = picked.prefix(context.field.isFileList ? context.fileRoom : 1)
        Task {
            var copies: [URL] = []
            for url in urls { if let copy = await UploadStore.copy(url, owner: owner) { copies.append(copy) } }
            context.receiveFiles(copies, overflow: urls.count < picked.count)
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

extension View {
    @ViewBuilder
    fileprivate func photoPicker(
        _ room: Int?, isPresented: Binding<Bool>, item: Binding<PhotosPickerItem?>, items: Binding<[PhotosPickerItem]>,
        pick: @escaping ([PhotosPickerItem]) -> Void
    ) -> some View {
        if let room {
            photosPicker(isPresented: isPresented, selection: items, maxSelectionCount: room, matching: .images)
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

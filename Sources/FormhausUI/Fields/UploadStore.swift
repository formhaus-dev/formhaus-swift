import Foundation

enum UploadStore {
    static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("formhaus-uploads", isDirectory: true)
    }

    static func copy(_ source: URL) -> URL? {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let target = place(source.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: source, to: target)
            return target
        } catch {
            return nil
        }
    }

    static func write(_ data: Data, ext: String) -> URL? {
        let target = place("photo.\(ext)")
        return (try? data.write(to: target)) == nil ? nil : target
    }

    static func discard(_ value: String) {
        guard let url = URL(string: value), url.isFileURL, owns(url) else { return }
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    static func owns(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(directory.standardizedFileURL.path + "/")
    }

    private static func place(_ name: String) -> URL {
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(name.isEmpty ? "file" : name)
    }
}

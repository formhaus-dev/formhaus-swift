import Foundation

@MainActor
enum UploadStore {
    private struct Upload {
        let owner: ObjectIdentifier
        let url: URL
    }

    private static var uploads: [String: Upload] = [:]

    nonisolated static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("formhaus-uploads", isDirectory: true)
    }

    static func copy(_ source: URL, owner: ObjectIdentifier) async -> URL? {
        let folder = UUID().uuidString
        let target = await Task.detached(priority: .userInitiated) { copyFile(source, into: folder) }.value
        return register(target, folder: folder, owner: owner)
    }

    static func write(_ data: Data, ext: String, owner: ObjectIdentifier) async -> URL? {
        let folder = UUID().uuidString
        let target = await Task.detached(priority: .userInitiated) { writeFile(data, name: "photo.\(ext)", into: folder) }.value
        return register(target, folder: folder, owner: owner)
    }

    static func owned(_ value: String, by owner: ObjectIdentifier) -> URL? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        guard text.lowercased().hasPrefix("file:"), let url = URL(string: text), url.isFileURL, let folder = folder(of: url),
            let upload = uploads[folder], upload.owner == owner, upload.url.standardizedFileURL == url.standardizedFileURL
        else { return nil }
        return upload.url
    }

    static func prune(owner: ObjectIdentifier, keeping values: Set<String>) {
        for (folder, upload) in uploads where upload.owner == owner && !values.contains(upload.url.absoluteString) {
            remove(folder)
        }
    }

    static func release(owner: ObjectIdentifier) {
        for (folder, upload) in uploads where upload.owner == owner { remove(folder) }
    }

    private static func register(_ target: URL?, folder: String, owner: ObjectIdentifier) -> URL? {
        guard let target else { return nil }
        uploads[folder] = Upload(owner: owner, url: target)
        return target
    }

    private static func remove(_ folder: String) {
        uploads[folder] = nil
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(folder, isDirectory: true))
    }

    private static func folder(of url: URL) -> String? {
        let parent = url.standardizedFileURL.deletingLastPathComponent()
        guard parent.deletingLastPathComponent().standardizedFileURL.path == directory.standardizedFileURL.path else { return nil }
        return parent.lastPathComponent
    }
}

private func prepare(_ folder: String) -> URL? {
    let url = UploadStore.directory.appendingPathComponent(folder, isDirectory: true)
    return (try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)) == nil ? nil : url
}

private func copyFile(_ source: URL, into folder: String) -> URL? {
    let scoped = source.startAccessingSecurityScopedResource()
    defer { if scoped { source.stopAccessingSecurityScopedResource() } }
    guard let base = prepare(folder) else { return nil }
    let name = source.lastPathComponent.isEmpty ? "file" : source.lastPathComponent
    let target = base.appendingPathComponent(name)
    return (try? FileManager.default.copyItem(at: source, to: target)) == nil ? nil : target
}

private func writeFile(_ data: Data, name: String, into folder: String) -> URL? {
    guard let base = prepare(folder) else { return nil }
    let target = base.appendingPathComponent(name)
    return (try? data.write(to: target)) == nil ? nil : target
}

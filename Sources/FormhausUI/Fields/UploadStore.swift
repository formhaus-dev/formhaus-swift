import Foundation

@MainActor
enum UploadStore {
    private struct Upload {
        let owner: ObjectIdentifier
        let url: URL
    }

    private static var uploads: [String: Upload] = [:]
    private static var retired: Set<ObjectIdentifier> = []

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
        guard let url = fileURL(value), let entry = entry(url), let upload = uploads[entry.folder], upload.owner == owner,
            upload.url.standardizedFileURL.path == entry.file.path, FileManager.default.fileExists(atPath: entry.file.path)
        else { return nil }
        return upload.url
    }

    static func names(owner: ObjectIdentifier) -> [String: String] {
        var names: [String: String] = [:]
        for upload in uploads.values where upload.owner == owner && FileManager.default.fileExists(atPath: upload.url.path) {
            names[upload.url.absoluteString] = upload.url.lastPathComponent
        }
        return names
    }

    static func isMissing(_ value: String) -> Bool {
        guard let url = fileURL(value), let entry = entry(url) else { return false }
        return !FileManager.default.fileExists(atPath: entry.file.path)
    }

    static func adopt(_ value: String, owner: ObjectIdentifier) -> Bool {
        guard let url = fileURL(value), url.absoluteString == value, let entry = entry(url) else { return true }
        guard FileManager.default.fileExists(atPath: entry.file.path) else { return false }
        if uploads[entry.folder].map({ retired.contains($0.owner) }) ?? true { uploads[entry.folder] = Upload(owner: owner, url: url) }
        return true
    }

    static func retire(owner: ObjectIdentifier) {
        retired.insert(owner)
    }

    static func prune(owner: ObjectIdentifier, keeping values: Set<String>) {
        for (folder, upload) in uploads where upload.owner == owner && !values.contains(upload.url.absoluteString) {
            remove(folder)
        }
    }

    static func discard(_ url: URL, owner: ObjectIdentifier) {
        guard let folder = entry(url)?.folder, uploads[folder]?.owner == owner else { return }
        remove(folder)
    }

    static func release(owner: ObjectIdentifier) {
        for (folder, upload) in uploads where upload.owner == owner { remove(folder) }
        retired.remove(owner)
    }

    private static func register(_ target: URL?, folder: String, owner: ObjectIdentifier) -> URL? {
        guard let target else { return nil }
        uploads[folder] = Upload(owner: owner, url: target)
        return target
    }

    private static func remove(_ folder: String) {
        uploads[folder] = nil
        let url = directory.appendingPathComponent(folder, isDirectory: true)
        guard !isLink(url), url.resolvingSymlinksInPath().deletingLastPathComponent().path == root.path else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func fileURL(_ value: String) -> URL? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        guard text.lowercased().hasPrefix("file:"), let url = URL(string: text), url.isFileURL else { return nil }
        return url
    }

    private static var root: URL { directory.resolvingSymlinksInPath().standardizedFileURL }

    private static func entry(_ url: URL) -> (folder: String, file: URL)? {
        let file = URL(fileURLWithPath: url.path).standardizedFileURL
        let folder = file.deletingLastPathComponent()
        let base = folder.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let name = folder.lastPathComponent
        guard base.path == root.path, UUID(uuidString: name)?.uuidString == name, !isLink(folder), !isLink(file) else { return nil }
        let resolved = file.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.deletingLastPathComponent().deletingLastPathComponent().path == root.path else { return nil }
        return (name, file)
    }
}

private func isLink(_ url: URL) -> Bool {
    (try? FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeSymbolicLink
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

@_spi(Renderer) import FormhausCore
import Foundation

struct FileRow {
    let index: Int
    let name: String
    let url: URL?
}

private func lastSegment(_ text: String) -> String {
    let path = text.prefix { $0 != "?" && $0 != "#" }
    let trimmed = path.reversed().drop { $0 == "/" }.reversed()
    let segment = String(trimmed.split(separator: "/", omittingEmptySubsequences: false).last ?? [])
    return segment.isEmpty ? text : segment
}

extension FormModel {
    public func pickedFiles(forKey key: String) -> [URL] {
        fileRows(engine.value(at: key)).compactMap(\.url)
    }

    func fileRows(_ value: JSONValue?) -> [FileRow] {
        let owner = ObjectIdentifier(self)
        return fileItems(value).enumerated().compactMap { index, item in
            guard let text = item.stringValue else {
                return item.objectValue?["name"]?.stringValue.map { FileRow(index: index, name: $0, url: nil) }
            }
            if let url = UploadStore.owned(text, by: owner) { return FileRow(index: index, name: url.lastPathComponent, url: url) }
            return text.isEmpty ? nil : FileRow(index: index, name: lastSegment(text), url: nil)
        }
    }

    func fileRoom(_ field: FormField, _ value: JSONValue?) -> Int {
        max(0, engine.fileLimit(field).count - listedFiles(value).count)
    }

    func addFiles(_ urls: [URL], to field: FormField, at key: String, overflow: Bool) {
        let items = fileItems(engine.value(at: key))
        let limit = engine.fileLimit(field)
        let held = listedFiles(.array(items)).count
        let added = Array(urls.prefix(max(0, limit.count - held)))
        for url in urls.dropFirst(added.count) { UploadStore.discard(url, owner: ObjectIdentifier(self)) }
        var notes: [String] = []
        if !added.isEmpty {
            let value = JSONValue.array(items + added.map { .string($0.absoluteString) })
            setValue(value, forKey: key)
            notes.append(text(forLabel: "itemAdded", ["item": .string(added.map(\.lastPathComponent).joined(separator: ", "))]))
            if held + added.count >= limit.count, let last = fileRows(value).last { requestFocus(removeFileKey(key, last.index)) }
        }
        if overflow || added.count < urls.count {
            notes.append(limit.message)
            self.field(key).showNotice(limit.message)
        }
        if !notes.isEmpty { announce(notes.joined(separator: " ")) }
    }

    func removeFile(at index: Int, forKey key: String) {
        var items = fileItems(engine.value(at: key))
        guard let row = fileRows(.array(items)).first(where: { $0.index == index }) else { return }
        items.remove(at: index)
        setValue(.array(items), forKey: key)
        if let url = row.url { UploadStore.discard(url, owner: ObjectIdentifier(self)) }
        let left = fileRows(.array(items)).map(\.index)
        let next = left.first { $0 >= index } ?? left.last
        requestFocus(next.map { removeFileKey(key, $0) } ?? key)
        announce(text(forLabel: "itemRemoved", ["item": .string(row.name)]))
    }

    func removeFileKey(_ key: String, _ index: Int) -> String {
        "\(key)#remove\(index)"
    }
}

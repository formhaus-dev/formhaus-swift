import CoreGraphics
import Observation

@MainActor
@Observable
final class ImageEntry {
    fileprivate(set) var image: CGImage?
    @ObservationIgnored fileprivate var loading = false
    @ObservationIgnored fileprivate var bytes = 0
}

@MainActor
final class OptionImages {
    static let shared = OptionImages()
    private var entries: [ImageKey: ImageEntry] = [:]
    private var order: [ImageKey] = []
    private var bytes = 0
    private let maxBytes = 48 * 1024 * 1024
    private let maxCount = 256

    func entry(_ key: ImageKey) -> ImageEntry {
        if let entry = entries[key] { return entry }
        let entry = ImageEntry()
        entries[key] = entry
        return entry
    }

    func cached(_ key: ImageKey) -> CGImage? {
        entries[key]?.image
    }

    func loaded(_ key: ImageKey) -> CGImage? {
        loadable(key.source) ? entry(key).image : nil
    }

    func prefetch(_ keys: [ImageKey]) {
        for key in keys where isInline(key.source) { load(key) }
    }

    func load(_ key: ImageKey) {
        guard loadable(key.source) else { return }
        let entry = entry(key)
        guard entry.image == nil, !entry.loading else { return }
        entry.loading = true
        Task {
            _ = await image(key)
            entry.loading = false
        }
    }

    func image(_ key: ImageKey) async -> CGImage? {
        let entry = entry(key)
        if let image = entry.image { return image }
        guard let image = await loadImage(key.source) else { return nil }
        store(image, key, entry)
        return image
    }

    private func loadable(_ source: String) -> Bool {
        isInline(source) || remoteImageURL(source) != nil
    }

    private func store(_ image: CGImage, _ key: ImageKey, _ entry: ImageEntry) {
        guard entry.image == nil else { return }
        entry.image = image
        entry.bytes = image.bytesPerRow * image.height
        bytes += entry.bytes
        order.append(key)
        while order.count > maxCount || bytes > maxBytes, order.count > 1 {
            let oldest = order.removeFirst()
            if let evicted = entries.removeValue(forKey: oldest) { bytes -= evicted.bytes }
        }
    }
}

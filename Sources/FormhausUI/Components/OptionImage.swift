import ImageIO
import SwiftUI

struct OptionImage: View {
    @Environment(\.formhausTokens) private var tokens
    let key: ImageKey
    var fit = false

    private var source: String { key.source }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(0, tokens.radii.control - tokens.spacing.s1), style: .continuous)
        Group {
            if fit {
                picture.scaledToFit()
            } else {
                Color.clear.aspectRatio(4 / 3, contentMode: .fit).overlay { picture.scaledToFill() }
            }
        }
        .background(tokens.colors.backgroundDisabled)
        .clipShape(shape)
        .accessibilityHidden(true)
        .onAppear { InlineImages.shared.prefetch([key]) }
    }

    @ViewBuilder private var picture: some View {
        if let image = isInline(source) ? InlineImages.shared.entry(key).image : nil {
            Image(decorative: image, scale: 1).resizable()
        } else if let url = URL(string: source), ["https", "http"].contains(url.scheme) {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable() } else { tokens.colors.backgroundDisabled }
            }
        } else {
            tokens.colors.backgroundDisabled
        }
    }
}

private func isInline(_ source: String) -> Bool {
    source.hasPrefix("data:image/")
}

struct ImageKey: Hashable, Sendable {
    let source: String
    private let digest: Int

    init(_ source: String, digest: Int? = nil) {
        self.source = source
        self.digest = digest ?? fullDigest(source)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(digest)
    }

    static func == (lhs: ImageKey, rhs: ImageKey) -> Bool {
        lhs.digest == rhs.digest && lhs.source == rhs.source
    }
}

private func fullDigest(_ source: String) -> Int {
    var hasher = Hasher()
    hasher.combine(source)
    return hasher.finalize()
}

@MainActor
@Observable
final class ImageEntry {
    fileprivate(set) var image: CGImage?
    @ObservationIgnored fileprivate var loading = false
    @ObservationIgnored fileprivate var bytes = 0
}

@MainActor
final class InlineImages {
    static let shared = InlineImages()
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

    func prefetch(_ keys: [ImageKey]) {
        for key in keys where isInline(key.source) { load(key, entry(key)) }
    }

    func image(_ key: ImageKey) async -> CGImage? {
        let entry = entry(key)
        if let image = entry.image { return image }
        let source = key.source
        guard let image = await Task.detached(priority: .userInitiated, operation: { decodeInline(source) }).value else { return nil }
        store(image, key, entry)
        return image
    }

    private func load(_ key: ImageKey, _ entry: ImageEntry) {
        guard entry.image == nil, !entry.loading else { return }
        entry.loading = true
        Task {
            _ = await image(key)
            entry.loading = false
        }
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

private func decodeInline(_ source: String) -> CGImage? {
    guard isInline(source), let comma = source.firstIndex(of: ","), source[..<comma].hasSuffix(";base64"),
        let data = Data(base64Encoded: String(source[source.index(after: comma)...])),
        let image = CGImageSourceCreateWithData(data as CFData, nil)
    else { return nil }
    return CGImageSourceCreateImageAtIndex(image, 0, nil)
}

struct ZoomButton: View {
    @Environment(\.formhausTokens) private var tokens
    let label: String
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(0, tokens.radii.control - tokens.spacing.s1), style: .continuous)
        Button(action: action) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: tokens.controls.iconButton * 0.44, weight: .semibold))
                .foregroundStyle(tokens.colors.text)
                .frame(width: tokens.controls.iconButton, height: tokens.controls.iconButton)
                .background(shape.fill(tokens.colors.background))
                .overlay(shape.strokeBorder(tokens.colors.border, lineWidth: 1))
                .shadow(color: tokens.colors.shadow, radius: 4, y: 2)
                .frame(minWidth: tokens.controls.hitTarget, minHeight: tokens.controls.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct ImageViewer: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.dismiss) private var dismiss
    let title: String
    let key: ImageKey
    let closeLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: tokens.spacing.s5) {
                Text(title).formhausText(.heading).frame(maxWidth: .infinity, alignment: .leading)
                IconButton(systemName: "xmark", label: closeLabel) { dismiss() }
            }
            .padding(.vertical, tokens.spacing.s7)
            .padding(.leading, tokens.spacing.s9)
            .padding(.trailing, tokens.spacing.s5)
            OptionImage(key: key, fit: true)
                .padding([.horizontal, .bottom], tokens.spacing.s9)
        }
        .frame(minWidth: 320, idealWidth: 560)
        .background(tokens.colors.background)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

struct IconButton: View {
    @Environment(\.formhausTokens) private var tokens
    let systemName: String
    let label: String
    var embedded = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: tokens.controls.iconButton * 0.44 * (embedded ? max(1, tokens.scale) : 1), weight: .semibold))
                .foregroundStyle(tokens.colors.textMuted)
                .frame(width: tokens.controls.iconButton, height: tokens.controls.iconButton)
                .frame(minWidth: tokens.controls.hitTarget, minHeight: tokens.controls.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(-(embedded ? (tokens.controls.hitTarget - tokens.controls.iconButton) / 2 + tokens.spacing.s1 : 0))
        .accessibilityLabel(label)
    }
}

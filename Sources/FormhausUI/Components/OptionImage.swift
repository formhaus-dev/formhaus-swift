import ImageIO
import SwiftUI

struct OptionImage: View {
    @Environment(\.formhausTokens) private var tokens
    let source: String
    var fit = false

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
        .onAppear { InlineImages.shared.prefetch([source]) }
    }

    @ViewBuilder private var picture: some View {
        if let image = InlineImages.shared.cached(source) {
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

@MainActor
@Observable
final class InlineImages {
    static let shared = InlineImages()
    private var cache: [String: CGImage] = [:]
    @ObservationIgnored private var order: [String] = []
    @ObservationIgnored private var loading: Set<String> = []

    func prefetch(_ sources: [String]) {
        for source in sources where isInline(source) && cache[source] == nil && !loading.contains(source) {
            loading.insert(source)
            Task {
                _ = await image(source)
                loading.remove(source)
            }
        }
    }

    func cached(_ source: String) -> CGImage? {
        cache[source]
    }

    func image(_ source: String) async -> CGImage? {
        if let hit = cache[source] { return hit }
        let image = await Task.detached(priority: .userInitiated) { decodeInline(source) }.value
        guard let image else { return nil }
        cache[source] = image
        order.append(source)
        if order.count > 128 { cache[order.removeFirst()] = nil }
        return image
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
    let source: String
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
            OptionImage(source: source, fit: true)
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

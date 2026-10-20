import SwiftUI

struct OptionImage: View {
    @Environment(\.formhausTokens) private var tokens
    let key: ImageKey
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
        .onAppear { OptionImages.shared.load(key) }
    }

    @ViewBuilder private var picture: some View {
        if let image = OptionImages.shared.loaded(key) {
            Image(decorative: image, scale: 1).resizable()
        } else {
            tokens.colors.backgroundDisabled
        }
    }
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
        .accessibilityLabel(Text(verbatim: label))
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
                Text(verbatim: title).formhausText(.heading).frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityLabel(Text(verbatim: title))
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
        .accessibilityLabel(Text(verbatim: label))
    }
}

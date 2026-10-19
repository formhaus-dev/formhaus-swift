import AppKit
import FormhausUI
import SwiftUI

enum Appearance: String, CaseIterable {
    case light
    case dark

    var scheme: ColorScheme { self == .light ? .light : .dark }
    var name: NSAppearance.Name { self == .light ? .aqua : .darkAqua }
}

struct SnapshotStyle {
    var appearance = Appearance.light
    var typeSize = DynamicTypeSize.large
    var width: CGFloat = 420
    var theme = FormhausTheme.pointer

    var suffix: String {
        let parts: [String?] = [appearance.rawValue, typeSize == .large ? nil : "large-type", width == 420 ? nil : "w\(Int(width))"]
        return parts.compactMap(\.self).joined(separator: "-")
    }
}

@MainActor
func renderPNG(_ view: some View, style: SnapshotStyle, to url: URL) throws {
    _ = NSApplication.shared
    let tokensBackground = style.appearance == .light ? Palette.light.background : Palette.dark.background
    let root =
        view
        .padding(24)
        .frame(width: style.width)
        .background(tokensBackground)
        .formhausTheme(style.theme)
        .environment(\.colorScheme, style.appearance.scheme)
        .environment(\.dynamicTypeSize, style.typeSize)
    let host = NSHostingView(rootView: root)
    host.appearance = NSAppearance(named: style.appearance.name)
    host.frame = CGRect(origin: .zero, size: CGSize(width: style.width, height: 10))
    host.layoutSubtreeIfNeeded()
    host.frame.size = host.fittingSize
    host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
    host.cacheDisplay(in: host.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])?.write(to: url)
}

var galleryDirectory: URL? {
    ProcessInfo.processInfo.environment["FORMHAUS_GALLERY"].map { URL(fileURLWithPath: $0, isDirectory: true) }
}

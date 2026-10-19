import AppKit
@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI

@MainActor
func renderSystem(_ name: String, _ model: FormModel, height: CGFloat = 900, behavior: FormBehavior = FormBehavior()) throws {
    guard let directory = galleryDirectory else { return }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let styles = [
        SnapshotStyle(appearance: .light, width: 520), SnapshotStyle(appearance: .dark, width: 520),
        SnapshotStyle(appearance: .light, typeSize: .accessibility2, width: 520),
    ]
    for style in styles {
        let view = NavigationStack {
            FormhausFormContent(model: model)
        }
        .formhausComponents(.system)
        .formhausBehavior(behavior)
        try renderSystemPNG(view, style: style, height: height, to: directory.appendingPathComponent("system-\(name)-\(style.suffix).png"))
    }
}

@MainActor
func renderSystemPNG(_ view: some View, style: SnapshotStyle, height: CGFloat, to url: URL) throws {
    _ = NSApplication.shared
    let root = view.frame(width: style.width, height: height)
        .formhausTheme(style.theme)
        .environment(\.colorScheme, style.appearance.scheme)
        .environment(\.dynamicTypeSize, style.typeSize)
    let host = NSHostingView(rootView: root)
    host.appearance = NSAppearance(named: style.appearance.name)
    host.frame = CGRect(origin: .zero, size: CGSize(width: style.width, height: height))
    for _ in 0..<4 {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        host.layoutSubtreeIfNeeded()
    }
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
    host.cacheDisplay(in: host.bounds, to: rep)
    let srgb = rep.converting(to: .sRGB, renderingIntent: .default) ?? rep
    try srgb.representation(using: .png, properties: [:])?.write(to: url)
}

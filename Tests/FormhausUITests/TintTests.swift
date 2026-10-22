import AppKit
import FormhausCore
import FormhausUI
import SwiftUI
import Testing

private let swatchForm: JSONValue = [
    "id": "t", "title": "T", "submit": ["label": "Send"],
    "fields": [["key": "swatch", "type": "x-swatch", "label": "Swatch"]],
]

@MainActor
private final class SwatchLog {
    var frame: CGRect?
}

private let hostTint = NSColor(srgbRed: 0, green: 0.8, blue: 0, alpha: 1)

@MainActor
private func swatchColor(_ components: FormComponents) throws -> NSColor? {
    _ = NSApplication.shared
    let log = SwatchLog()
    let model = FormModel(definition: try FormDefinition(json: swatchForm)) { _, _ in .ok }
    let view = NavigationStack {
        FormhausForm(model: model)
            .formhausComponents(
                components.field("x-swatch") { _ in
                    Rectangle().fill(.tint).frame(width: 60, height: 60)
                        .background { GeometryReader { proxy in Color.clear.onAppear { log.frame = proxy.frame(in: .named("root")) } } }
                })
    }
    .tint(Color(nsColor: hostTint))
    .coordinateSpace(name: "root")
    .frame(width: 520, height: 700)
    let host = NSHostingView(rootView: view)
    host.frame = CGRect(x: 0, y: 0, width: 520, height: 700)
    settle(host)
    guard let frame = log.frame, let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
    host.cacheDisplay(in: host.bounds, to: rep)
    let scale = CGFloat(rep.pixelsWide) / host.bounds.width
    return rep.colorAt(x: Int(frame.midX * scale), y: Int(frame.midY * scale))?.usingColorSpace(.sRGB)
}

private func close(_ color: NSColor?, _ expected: NSColor, within tolerance: CGFloat = 0.08) -> Bool {
    guard let color, let expected = expected.usingColorSpace(.sRGB) else { return false }
    return abs(color.redComponent - expected.redComponent) < tolerance && abs(color.greenComponent - expected.greenComponent) < tolerance
        && abs(color.blueComponent - expected.blueComponent) < tolerance
}

@Suite("Tint", .serialized)
@MainActor
struct TintTests {
    @Test("custom fields in the system set keep the host tint")
    func systemTint() throws {
        #expect(close(try swatchColor(.system), hostTint))
    }

    @Test("the formhaus set tints with the theme primary")
    func standardTint() throws {
        let primary = NSColor(FormhausTheme.standard.light.primary)
        let color = try swatchColor(.standard)
        #expect(!close(color, hostTint, within: 0.3))
        #expect(close(color, primary, within: 0.25))
    }
}

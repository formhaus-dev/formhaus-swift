import AppKit
import FormhausCore
import FormhausUI
import SwiftUI

struct MacForm: View {
    let model: FormModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.definition.title ?? "").font(.largeTitle.weight(.bold))
                    if let description = model.definition.description {
                        Text(description).font(.body).foregroundStyle(.secondary)
                    }
                }
                FormhausFormContent(model: model)
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}

func desktopLayout(_ data: Data) throws -> Data {
    guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let steps = root["steps"] as? [[String: Any]]
    else { return data }
    root["steps"] = steps.map { step in
        var step = step
        step["fields"] = (step["fields"] as? [[String: Any]])?.map { field in
            var field = field
            if field["columns"] != nil { field["columns"] = 4 }
            return field
        }
        return step
    }
    return try JSONSerialization.data(withJSONObject: root)
}

@MainActor
func render(definition: URL, output: URL, size: CGSize) throws {
    let source = try desktopLayout(Data(contentsOf: definition))
    let localized = try localize(JSONValue(parsing: source), overlay: .object(JSONObject()), lang: "en")
    let model = FormModel(localized: localized) { _, _ in .ok }
    model.start()
    let host = NSHostingView(rootView: MacForm(model: model))
    let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .aqua)
    window.contentView = host
    host.frame = CGRect(origin: .zero, size: size)
    for _ in 0..<20 {
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw CocoaError(.fileWriteUnknown) }
    host.cacheDisplay(in: host.bounds, to: bitmap)
    guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try data.write(to: output)
}

let arguments = CommandLine.arguments
guard arguments.count == 5, let width = Double(arguments[3]), let height = Double(arguments[4]) else {
    FileHandle.standardError.write(Data("usage: RenderMac <definition.json> <output.png> <width> <height>\n".utf8))
    exit(2)
}
NSApplication.shared.setActivationPolicy(.prohibited)
try MainActor.assumeIsolated {
    try render(definition: URL(fileURLWithPath: arguments[1]), output: URL(fileURLWithPath: arguments[2]), size: CGSize(width: width, height: height))
}

import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

private let pair: JSONValue = [["value": "a", "label": "Alpha"], ["value": "b", "label": "Beta"]]

private let invalidFields: [(String, JSONValue)] = [
    ("radio", ["key": "f", "type": "radio", "label": "Plan", "options": pair]),
    ("multiselect", ["key": "f", "type": "multiselect", "label": "Plan", "options": pair]),
    (
        "pictures",
        [
            "key": "f", "type": "radio", "label": "Colour",
            "options": [
                ["value": "a", "label": "Violet", "image": .string(swatch)], ["value": "b", "label": "Sand", "image": .string(swatch)],
            ],
        ]
    ),
    ("scale", ["key": "f", "type": "scale", "label": "Ease", "validation": ["min": 1, "max": 5]]),
    ("rating", ["key": "f", "type": "rating", "label": "Stay", "validation": ["max": 5]]),
    ("checkbox", ["key": "f", "type": "checkbox", "label": "I agree"]),
    ("switch", ["key": "f", "type": "switch", "label": "News"]),
    (
        "matrix",
        [
            "key": "m", "type": "section", "layout": "matrix", "title": "Agree?",
            "fields": [["key": "f", "type": "radio", "label": "Goals are clear", "options": pair]],
        ]
    ),
]

@MainActor
private final class Frames {
    var frames: [String: CGRect] = [:]
}

@MainActor
private func errorPixels(_ host: NSView) -> Int {
    settle(host)
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return 0 }
    host.cacheDisplay(in: host.bounds, to: rep)
    let srgb = rep.converting(to: .sRGB, renderingIntent: .default) ?? rep
    let error = NSColor(Palette.light.error).usingColorSpace(.sRGB) ?? .red
    var count = 0
    for x in 0..<srgb.pixelsWide {
        for y in 0..<srgb.pixelsHigh {
            guard let color = srgb.colorAt(x: x, y: y) else { continue }
            let distance = max(
                abs(color.redComponent - error.redComponent), abs(color.greenComponent - error.greenComponent),
                abs(color.blueComponent - error.blueComponent))
            if distance < 0.06 { count += 1 }
        }
    }
    return count
}

@Suite("Error states of choice controls", .serialized)
@MainActor
struct ErrorStateTests {
    @Test("an invalid control paints the error colour and an empty one does not", arguments: invalidFields.map(\.0))
    func errorBorder(name: String) async throws {
        _ = await OptionImages.shared.image(ImageKey(swatch))
        let field = try #require(invalidFields.first { $0.0 == name }?.1)
        let definition = try FormDefinition(json: ["id": "e", "title": "E", "submit": ["label": "Send"], "fields": [field]])
        let model = FormModel(definition: definition) { _, _ in nil }
        let view = FormFields(model: model)
            .padding(16)
            .background(Palette.light.background)
            .formhausTheme(.touch)
            .environment(\.colorScheme, .light)
        let host = host(view, width: 393, height: 700)
        host.appearance = NSAppearance(named: .aqua)
        #expect(errorPixels(host) == 0, "\(name) is red while valid")
        model.setErrors(["f": " "])
        #expect(errorPixels(host) > 40, "\(name) does not show its error")
    }

    @Test("a rating row stays inside narrow widths at every text size", arguments: [5, 10])
    func ratingFits(points: Int) throws {
        let field: JSONValue = ["key": "r", "type": "rating", "label": "Rate", "validation": ["max": .number(Double(points))]]
        let definition = try FormDefinition(json: ["id": "r", "title": "R", "submit": ["label": "Send"], "fields": [field]])
        let model = FormModel(definition: definition) { _, _ in nil }
        for size in [DynamicTypeSize.large, .xxxLarge, .accessibility3, .accessibility5] {
            for width: CGFloat in [277, 350, 440] {
                let log = Frames()
                let view = FormFields(model: model)
                    .environment(\.formhausMeasuring, true)
                    .coordinateSpace(name: measureSpace)
                    .onPreferenceChange(MeasuredFrames.self) { frames in MainActor.assumeIsolated { log.frames = frames } }
                    .formhausTheme(.touch)
                    .environment(\.dynamicTypeSize, size)
                _ = host(view, width: width, height: 1600)
                let control = try #require(log.frames["r/control"])
                #expect(control.minX >= -0.5 && control.maxX <= width + 0.5, "\(points) stars, \(size), width \(width): \(control)")
                #expect(control.height >= FormhausTheme.touch.controls.hitTarget - 0.5)
            }
        }
    }
}

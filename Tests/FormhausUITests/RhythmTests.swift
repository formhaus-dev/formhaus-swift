import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

private let types = [
    "text", "email", "phone", "number", "password", "textarea", "autocomplete", "select", "radio", "multiselect", "date", "time",
    "datetime", "file", "scale", "rating", "checkbox", "switch",
]

@MainActor
final class FrameLog {
    var frames: [String: CGRect] = [:]
}

@Suite("Vertical rhythm", .serialized)
@MainActor
struct RhythmTests {
    @Test("every field type keeps the label, control and gap spacing")
    func rhythm() throws {
        let fields: [JSONValue] = types.map { type in
            ["key": .string(type), "type": .string(type), "label": .string(type), "options": [["value": "a", "label": "A"]]]
        }
        let definition = try FormDefinition(json: ["id": "r", "title": "R", "submit": ["label": "Send"], "fields": .array(fields)])
        let model = FormModel(definition: definition) { _, _ in nil }
        let log = FrameLog()
        let view = FormFields(model: model)
            .environment(\.formhausMeasuring, true)
            .coordinateSpace(name: measureSpace)
            .onPreferenceChange(MeasuredFrames.self) { frames in MainActor.assumeIsolated { log.frames = frames } }
            .formhausTheme(.pointer)
        _ = host(view, width: 480, height: 2600)
        let tokens = FormhausTokens(theme: .pointer, dark: false, typeSize: .large, reduceMotion: false)
        for type in types {
            guard let field = log.frames["\(type)/field"], let control = log.frames["\(type)/control"] else {
                Issue.record("no frames for \(type)")
                continue
            }
            if let label = log.frames["\(type)/label"] {
                #expect(abs(label.minY - field.minY) < 0.5, "label inset of \(type)")
                #expect(abs(control.minY - label.maxY - tokens.spacing.s3) < 0.5, "label to control of \(type)")
            }
        }
        for (previous, next) in zip(types, types.dropFirst()) {
            guard let above = log.frames["\(previous)/field"], let below = log.frames["\(next)/field"] else { continue }
            #expect(abs(below.minY - above.maxY - tokens.spacing.gap) < 0.5, "gap between \(previous) and \(next)")
        }
    }
}

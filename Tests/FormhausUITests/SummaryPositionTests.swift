import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

@MainActor
private func invalidForm() throws -> FormModel {
    let fields: [JSONValue] = (1...6).map { index -> JSONValue in
        ["key": .string("f\(index)"), "type": "text", "label": .string("Field \(index)"), "validation": ["required": true]]
    }
    let json: JSONValue = ["id": "s", "title": "S", "submit": ["label": "Send"], "fields": .array(fields)]
    return FormModel(definition: try FormDefinition(json: json)) { _, _ in nil }
}

@Suite("Error summary position", .serialized)
@MainActor
struct SummaryPositionTests {
    @Test("the formhaus set places the summary after the fields and before the actions")
    func order() async throws {
        let form = try invalidForm()
        let log = FrameLog()
        let view = FormhausForm(model: form)
            .environment(\.formhausMeasuring, true)
            .coordinateSpace(name: measureSpace)
            .onPreferenceChange(MeasuredFrames.self) { frames in MainActor.assumeIsolated { log.frames = frames } }
        let hosted = host(view, height: 2400)
        await form.submit()
        settle(hosted)
        let summary = try #require(log.frames["summary"])
        let firstField = try #require(log.frames["f1/field"])
        let lastField = try #require(log.frames["f6/field"])
        let primary = try #require(log.frames["actions/primary"])
        #expect(summary.minY >= lastField.maxY)
        #expect(summary.maxY <= primary.minY)
        #expect(firstField.minY < lastField.minY)
    }

    @Test("focusing a summary below the fold scrolls it fully into view")
    func visible() async throws {
        let form = try invalidForm()
        let log = FrameLog()
        let view = FormhausForm(model: form)
            .environment(\.formhausMeasuring, true)
            .coordinateSpace(name: measureSpace)
            .onPreferenceChange(MeasuredFrames.self) { frames in MainActor.assumeIsolated { log.frames = frames } }
        let hosted = host(view, height: 500)
        let window = NSWindow(contentRect: hosted.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = hosted
        settle(hosted)
        await form.submit()
        for _ in 0..<10 { settle(hosted) }
        withExtendedLifetime(window) {}
        let summary = try #require(log.frames["summary"])
        #expect(summary.minY >= 0 && summary.maxY <= 500)
    }
}

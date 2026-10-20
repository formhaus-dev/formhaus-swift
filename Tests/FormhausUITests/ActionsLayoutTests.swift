import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

private let flow: JSONValue = [
    "id": "flow", "title": "Flow", "submit": ["label": "Book trip"],
    "steps": [
        ["id": "one", "title": "One", "fields": [["key": "a", "type": "text", "label": "A"]]],
        [
            "id": "two", "title": "Two", "skip": ["label": "Skip for now"],
            "fields": [["key": "b", "type": "text", "label": "B"]],
        ],
        ["id": "three", "title": "Three", "fields": [["key": "c", "type": "text", "label": "C"]]],
    ],
]

@MainActor
func secondStep() async throws -> FormModel {
    let model = FormModel(definition: try FormDefinition(json: flow)) { _, _ in nil }
    await model.next()
    return model
}

@Suite("Actions layout", .serialized)
@MainActor
struct ActionsLayoutTests {
    private func frames(
        _ layout: ActionsLayout, width: CGFloat = 390, backPlacement: BackPlacement = .automatic
    ) async throws -> [String: CGRect] {
        let model = try await secondStep()
        let log = FrameLog()
        let view = FormActionsSlot(model: model)
            .environment(\.formhausActionsLayout, layout)
            .formhausBehavior(FormBehavior(backPlacement: backPlacement))
            .environment(\.formhausMeasuring, true)
            .coordinateSpace(name: measureSpace)
            .onPreferenceChange(MeasuredFrames.self) { frames in MainActor.assumeIsolated { log.frames = frames } }
            .formhausTheme(.pointer)
        _ = host(view, width: width, height: 400)
        return log.frames
    }

    @Test("compact width stacks the primary above a full-width Back", arguments: [BackPlacement.automatic, .bottom])
    func stacked(placement: BackPlacement) async throws {
        let frames = try await frames(.stacked, backPlacement: placement)
        let primary = try #require(frames["actions/primary"])
        let back = try #require(frames["actions/back"])
        let tokens = FormhausTokens(theme: .pointer, dark: false, typeSize: .large, reduceMotion: false)
        #expect(abs(back.minY - primary.maxY - tokens.spacing.s3) < 0.5)
        #expect(abs(primary.width - 390) < 0.5)
        #expect(abs(back.width - primary.width) < 0.5)
    }

    @Test("regular width puts Back on the left and the primary at its own size on the right")
    func row() async throws {
        let frames = try await frames(.row, width: 640)
        let primary = try #require(frames["actions/primary"])
        let back = try #require(frames["actions/back"])
        #expect(abs(back.midY - primary.midY) < 0.5)
        #expect(back.minX < 0.5)
        #expect(abs(primary.maxX - 640) < 0.5)
        #expect(primary.width < 640 / 2)
    }

    @Test("both layouts render", arguments: [ActionsLayout.stacked, .row])
    func gallery(layout: ActionsLayout) async throws {
        let first = FormModel(definition: try FormDefinition(json: flow)) { _, _ in nil }
        let sheet = GallerySheet(title: "actions", rows: [("first", first), ("second", try await secondStep())])
            .environment(\.formhausActionsLayout, layout)
        try renderGallery("actions-\(layout == .stacked ? "stacked" : "row")", sheet, widths: [390, 640])
    }
}

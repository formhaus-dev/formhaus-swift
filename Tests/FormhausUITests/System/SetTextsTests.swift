import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing
import Vision

@testable import FormhausUI

@MainActor
func renderedLines(_ view: NSView) throws -> [String] {
    view.frame.size.height = max(view.fittingSize.height, 200)
    settle(view)
    let size = view.bounds.size
    let rep = try #require(
        NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    rep.size = size
    view.cacheDisplay(in: view.bounds, to: rep)
    let image = try #require(rep.cgImage)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    try VNImageRequestHandler(cgImage: image).perform([request])
    let found = (request.results ?? []).compactMap { item in item.topCandidates(1).first.map { (item.boundingBox, $0.string) } }
    return found.sorted { abs($0.0.midY - $1.0.midY) > 0.005 ? $0.0.midY > $1.0.midY : $0.0.minX < $1.0.minX }.map(\.1)
}

private let survey: JSONValue = [
    "id": "start", "title": "Start a project", "submit": ["label": "Send request"],
    "steps": [
        [
            "id": "scope", "title": "Scope", "description": "Tell us what you need",
            "fields": [
                [
                    "key": "name", "type": "text", "label": "Your name", "placeholder": "Grace Hopper",
                    "helperText": "As it appears on invoices",
                ],
                [
                    "key": "services", "type": "multiselect", "label": "Services", "validation": ["required": true],
                    "options": [["value": "d", "label": "Design"], ["value": "v", "label": "Development"]],
                ],
                [
                    "key": "budget", "type": "radio", "label": "Budget",
                    "options": [["value": "s", "label": "Under ten thousand"], ["value": "l", "label": "Above ten thousand"]],
                ],
                [
                    "key": "ease", "type": "scale", "label": "How sure are you",
                    "options": [["value": "1", "label": "Exploring"], ["value": "5", "label": "Decided"]],
                ],
                ["key": "brief", "type": "textarea", "label": "Project brief", "placeholder": "Goals and deadlines"],
            ],
        ],
        ["id": "contact", "title": "Contact", "fields": [["key": "email", "type": "email", "label": "Email"]]],
    ],
]

private func words(_ text: String) -> [Substring] {
    text.lowercased().split { !$0.isLetter && !$0.isNumber }
}

private func shows(_ line: String, _ text: String) -> Bool {
    if line.contains(text) { return true }
    let expected = words(text)
    let seen = Set(words(line))
    return expected.count > 2 && Double(expected.count { seen.contains($0) }) >= Double(expected.count) * 0.75
}

private let ordered = [
    "Step 1 of 2", "Scope", "Tell us what you need", "Your name", "Services", "Design", "Development", "Budget", "Under ten thousand",
    "Above ten thousand", "How sure are you", "Exploring", "Decided", "Project brief", "Continue",
]
private let placed = ["Grace Hopper", "As it appears on invoices", "Goals and deadlines"]

@Suite("Every set shows the same definition texts", .serialized)
@MainActor
struct SetTextsTests {
    @Test("the formhaus and system sets show every text of the step in the same order", arguments: [false, true])
    func sameTexts(system: Bool) throws {
        let model = FormModel(definition: try FormDefinition(json: survey)) { _, _ in nil }
        let view = host(FormhausFormContent(model: model).formhausComponents(system ? .system : .standard), height: 1600)
        let lines = try renderedLines(view)
        let positions = ordered.map { text in lines.firstIndex { shows($0, text) } }
        #expect(!positions.contains(nil), "missing \(zip(ordered, positions).filter { $0.1 == nil }.map(\.0)) in \(lines)")
        let found = positions.compactMap(\.self)
        #expect(found == found.sorted(), "out of order: \(lines)")
        for text in placed { #expect(lines.contains { shows($0, text) }, "missing \(text) in \(lines)") }
    }
}

import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

@MainActor
final class ItemLog {
    var hasContent: [Bool] = []
    var request: [@MainActor () -> Void] = []
}

private struct GroupSpy: View {
    let context: GroupContext
    let log: ItemLog

    var body: some View {
        log.hasContent = context.items.map(\.hasContent)
        log.request = context.items.map(\.requestRemove)
        return VStack { ForEach(context.items) { $0.content } }
    }
}

@Suite("Review fixes", .serialized)
@MainActor
struct ReviewTests {
    @Test("group items report content as it is typed")
    func hasContent() throws {
        let json: JSONValue = [
            "id": "g", "title": "G", "submit": ["label": "Send"],
            "fields": [
                [
                    "key": "team", "type": "group", "label": "Team", "defaultItems": 2,
                    "fields": [["key": "name", "type": "text", "label": "Name"]],
                ]
            ],
        ]
        let form = FormModel(definition: try FormDefinition(json: json)) { _, _ in nil }
        let log = ItemLog()
        let components = FormComponents.standard
            .group { GroupSpy(context: $0, log: log) }
            .confirmDialog { context in Button(context.confirmLabel, action: context.confirm) }
        let view = host(FormhausFormContent(model: form).formhausComponents(components))
        #expect(log.hasContent == [false, false])
        form.setValue("Ada", forKey: "team.1.name")
        settle(view)
        #expect(log.hasContent == [false, true])
        log.request.first?()
        settle(view)
        #expect(form.group("team").items.count == 1)
    }

    @Test("thousands of picture options render and select quickly")
    func largeLists() throws {
        let many: [JSONValue] = (0..<3000).map { index in
            ["value": .string("v\(index)"), "label": .string("Label \(index)"), "image": .string("https://example.invalid/\(index).png")]
        }
        let json: JSONValue = [
            "id": "h", "title": "H", "submit": ["label": "Send"],
            "fields": [
                ["key": "big", "type": "radio", "label": "Big", "options": .array(many)],
                [
                    "key": "inline", "type": "radio", "label": "Inline", "layout": "inline",
                    "options": [["value": "x", "label": .string(String(repeating: "long ", count: 200))]],
                ],
                [
                    "key": "m", "type": "section", "layout": "matrix", "title": "M",
                    "fields": [
                        ["key": "m1", "type": "radio", "label": "R1", "options": [["value": "a", "label": "A"]]],
                        [
                            "key": "m2", "type": "radio", "label": "R2",
                            "options": [["value": "a", "label": "A"], ["value": "b", "label": "B"]],
                        ],
                    ],
                ],
            ],
        ]
        let form = FormModel(definition: try FormDefinition(json: json)) { _, _ in nil }
        let start = Date()
        let view = host(ScrollView { FormhausFormContent(model: form) }, width: 360, height: 900)
        #expect(Date().timeIntervalSince(start) < 2)
        let select = Date()
        form.setValue("v5", forKey: "big")
        settle(view)
        #expect(Date().timeIntervalSince(select) < 0.5)
        #expect(view.fittingSize.width <= 360)
    }

    @Test("picked files are copied into the upload folder and removed on clear")
    func uploads() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("formhaus-source-\(UUID().uuidString).txt")
        try Data("cv".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let copy = try #require(UploadStore.copy(source))
        #expect(UploadStore.owns(copy))
        #expect(FileManager.default.fileExists(atPath: copy.path))
        UploadStore.discard(copy.absoluteString)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
        UploadStore.discard(source.absoluteString)
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test("labels added for 0.20 resolve and can be overridden")
    func upcomingLabels() throws {
        let form = FormModel(
            definition: try FormDefinition(json: signupDefinition), options: FormRendererOptions(labels: .catalog(["clear": "Leeren"]))
        ) { _, _ in nil }
        #expect(form.text(forLabel: "clear") == "Leeren")
        #expect(form.text(forLabel: "chooseFile") == "Choose file")
        #expect(form.text(forLabel: "stepTitle", ["index": 2]) == "Step 2")
        #expect(form.text(forLabel: "stepErrors", ["count": 3]) == "Errors: 3")
        let context = FieldContext(field: form.structure.visibleFields[0], model: form)
        #expect(context.accessibilityName == "Email, required")
    }
}

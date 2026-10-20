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

    @Test("picture options render lazily and a selection re-renders only the cards that change")
    func largeLists() throws {
        let many: [JSONValue] = (0..<30).map { index in
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
        let log = RenderLog()
        let view = host(ScrollView { FormhausFormContent(model: form) }.environment(\.formhausRenderLog, log), width: 360, height: 900)
        let rendered = log.bodies.keys.filter { $0.hasPrefix("v") }
        #expect(!rendered.isEmpty)
        #expect(rendered.count < 30)
        log.bodies = [:]
        form.setValue("v1", forKey: "big")
        settle(view)
        #expect(log.bodies.keys.filter { $0.hasPrefix("v") }.sorted() == ["v1"])
        log.bodies = [:]
        form.setValue("v0", forKey: "big")
        settle(view)
        #expect(log.bodies.keys.filter { $0.hasPrefix("v") }.sorted() == ["v0", "v1"])
        #expect(view.fittingSize.width <= 360)
    }

    @Test("uploads are owned by their model and only their own folders are removed")
    func uploads() async throws {
        let manager = FileManager.default
        let source = manager.temporaryDirectory.appendingPathComponent("formhaus-source-\(UUID().uuidString).txt")
        try Data("cv".utf8).write(to: source)
        defer { try? manager.removeItem(at: source) }
        let owner = ObjectIdentifier(CallLog())
        let copy = try #require(await UploadStore.copy(source, owner: owner))
        #expect(UploadStore.owns(copy))
        #expect(!UploadStore.owns(source))
        let crafted = try #require(URL(string: UploadStore.directory.absoluteString + "x/..%2F..%2Fvictim/f"))
        #expect(!UploadStore.owns(crafted))
        UploadStore.prune(owner: owner, keeping: [copy.absoluteString])
        #expect(manager.fileExists(atPath: copy.path))
        UploadStore.prune(owner: owner, keeping: [])
        #expect(!manager.fileExists(atPath: copy.path))
        #expect(manager.fileExists(atPath: source.path))
        let second = try #require(await UploadStore.copy(source, owner: owner))
        UploadStore.release(owner: owner)
        #expect(!manager.fileExists(atPath: second.path))
        #expect(manager.fileExists(atPath: UploadStore.directory.path))
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

import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

private let recalling: JSONValue = [
    "id": "r", "title": "R", "formatVersion": "1.5", "submit": ["label": "Send"],
    "steps": [
        [
            "id": "about", "title": "About {{name}}", "description": "Hi {{name}}",
            "fields": [
                ["key": "name", "type": "text", "label": "Name"],
                [
                    "key": "s", "type": "section", "title": "Section {{name}}", "description": "For {{name}}",
                    "fields": [
                        [
                            "key": "email", "type": "email", "label": "Mail for {{name}}", "helperText": "Help {{name}}",
                            "placeholder": "PH {{name}}",
                        ]
                    ],
                ],
                [
                    "key": "team", "type": "group", "label": "Team of {{name}}", "helperText": "Add {{name}}",
                    "itemLabel": "{label} {index}: {{member}}",
                    "fields": [["key": "member", "type": "text", "label": "Role of {{member}} for {{name}}"]],
                ],
                ["key": "plan", "type": "radio", "label": "Plan", "options": [["value": "pro", "label": "Pro {{name}}"]]],
            ],
        ],
        ["id": "next", "title": "Next", "fields": [["key": "notes", "type": "text", "label": "Notes"]]],
    ],
]

@MainActor
final class RecallLog {
    var progress: [String?] = []
    var sections: [String] = []
    var groups: [String] = []
    var items: [String] = []
}

private func capturing(_ base: FormComponents, _ log: RecallLog) -> FormComponents {
    base
        .progress { context in
            log.progress = [context.stepTitle, context.stepDescription] + (context.steps ?? []).map(\.title)
            return EmptyView()
        }
        .section { context in
            log.sections = [context.title, context.description ?? ""]
            return context.content
        }
        .group { context in
            log.groups = [context.label, context.helperText ?? "", context.group.label ?? ""]
            log.items = context.items.map(\.title)
            return VStack { ForEach(context.items) { $0.content } }
        }
}

private let values: JSONObject = ["name": "Ada", "team": [["member": "Bob"]]]

@Suite("Answer recall in the renderer", .serialized)
@MainActor
struct RecallViewTests {
    @Test("fields, sections, groups and steps show resolved texts", arguments: [false, true])
    func slots(system: Bool) throws {
        let form = try model(recalling, values: values)
        let log = RecallLog()
        let view = FormhausFormContent(model: form).formhausComponents(capturing(system ? .system : .standard, log))
            .formhausBehavior(FormBehavior(stepErrorMarks: true))
        _ = host(view)
        #expect(log.progress == ["About Ada", "Hi Ada", "About Ada", "Next"])
        #expect(log.sections == ["Section Ada", "For Ada"])
        #expect(log.groups == ["Team of Ada", "Add Ada", "Team of {{name}}"])
        #expect(log.items == ["Team of Ada 1: Bob"])
        let email = try #require(form.definition.allFieldsForTests.first { $0.key == "email" })
        let context = FieldContext(field: email, model: form)
        #expect([context.label, context.helperText, context.placeholder] == ["Mail for Ada", "Help Ada", "PH Ada"])
        let member = try #require(form.definition.allFieldsForTests.first { $0.key == "team" }?.items.first)
        #expect(FieldContext(field: member, key: "team.0.member", model: form).label == "Role of Bob for Ada")
        let plan = try #require(form.definition.allFieldsForTests.first { $0.key == "plan" })
        #expect(FieldContext(field: plan, model: form).options.map(\.label) == ["Pro {{name}}"])
    }

    @Test("a recalled answer is drawn as plain text, never as Markdown")
    func plainText() throws {
        let hostile = "**bold** [x](https://evil)"
        let form = try model(recalling, values: ["name": .string(hostile)])
        let email = try #require(form.definition.allFieldsForTests.first { $0.key == "email" })
        let context = FieldContext(field: email, model: form)
        #expect(context.label == "Mail for \(hostile)")
        #expect(context.accessibilityName == "Mail for \(hostile)")
        #expect(form.texts(for: try #require(form.structure.currentStep)).title == "About \(hostile)")
        let log = FrameLog()
        let view = FormFields(model: form)
            .environment(\.formhausMeasuring, true)
            .coordinateSpace(name: measureSpace)
            .onPreferenceChange(MeasuredFrames.self) { frames in MainActor.assumeIsolated { log.frames = frames } }
            .formhausTheme(.pointer)
        _ = host(view, width: 900, height: 1200)
        let drawn = try #require(log.frames["email/label"]).width
        let verbatim = width(of: FieldLabel(text: context.label, required: false, requiredLabel: ""))
        let markdown = width(of: Text(LocalizedStringKey(context.label)).formhausText(.label))
        #expect(abs(drawn - verbatim) < 0.5)
        #expect(abs(drawn - markdown) > 10)
    }

    @Test("lang and formatRecall from the renderer options reach the engine")
    func formatting() throws {
        let options = FormRendererOptions(lang: "de", formatRecall: { answer, _, locale in "\(locale):\(answer.stored)" })
        let form = try model(recalling, values: values, options: options)
        let email = try #require(form.definition.allFieldsForTests.first { $0.key == "email" })
        #expect(FieldContext(field: email, model: form).label == "Mail for de:Ada")
    }

    @Test("error group titles follow the recalled answer")
    func errorTitles() throws {
        let form = try model(recalling, values: values)
        form.setErrors(["email": "Bad"])
        #expect(form.errorGroups.map(\.title) == ["About Ada"])
        #expect(form.errorGroups.first?.entries.first?.label == "Mail for Ada")
        form.setValue("Grace", forKey: "name")
        #expect(form.errorGroups.map(\.title) == ["About Grace"])
    }

    private func width(of view: some View) -> CGFloat {
        let host = NSHostingView(rootView: view.fixedSize().formhausTheme(.pointer))
        return host.fittingSize.width
    }
}

extension FormDefinition {
    var allFieldsForTests: [FormField] {
        (steps ?? []).flatMap(\.fields).flatMap { node -> [FormField] in
            switch node {
            case .field(let field): [field]
            case .section(let section): section.fields.compactMap(\.field)
            }
        }
    }
}

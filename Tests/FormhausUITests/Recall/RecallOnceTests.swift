@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI
import Testing

private let typed: JSONValue = [
    "id": "o", "title": "O", "formatVersion": "1.5", "submit": ["label": "Send"],
    "steps": [
        [
            "id": "one", "title": "Step {{name}}", "description": "About {{name}}",
            "fields": [
                ["key": "name", "type": "text", "label": "Name"],
                ["key": "x", "type": "text", "label": "X"],
                [
                    "key": "s", "type": "section", "title": "Section {{name}}", "description": "For {{name}}",
                    "fields": [
                        [
                            "key": "mail", "type": "email", "label": "Mail {{name}}", "helperText": "Help {{name}}",
                            "placeholder": "PH {{name}}",
                        ]
                    ],
                ],
                [
                    "key": "team", "type": "group", "label": "Team {{name}}", "helperText": "Add {{name}}",
                    "itemLabel": "{{member}} {index}",
                    "fields": [["key": "member", "type": "text", "label": "Member {{member}}"]],
                ],
            ],
        ],
        ["id": "two", "title": "Two", "fields": [["key": "notes", "type": "text", "label": "Notes"]]],
    ],
]

@MainActor
final class SlotCapture {
    var section: SectionContext?
    var group: GroupContext?
    var progress: ProgressContext?
}

@Suite("Recall runs once", .serialized)
@MainActor
struct RecallOnceTests {
    @Test("resolved output passed back through every public path keeps a typed {{x}} literal")
    func typedTokensStayLiteral() throws {
        let values: JSONObject = ["name": "{{x}}", "x": "LEAK", "team": [["member": "{{x}}"]]]
        let form = try model(typed, values: values)
        let (section, group, progress) = try rendered(form)
        let step = try #require(form.structure.currentStep)
        let mail = try #require(section.section.fields.first?.field)
        let member = try #require(group.group.items.first)

        let first = FieldContext(field: mail, model: form)
        let again = FieldContext(field: first.field, model: form)
        let item = FieldContext(field: member, key: "team.0.member", model: form)
        let texts = [
            first.label, first.helperText, first.placeholder, first.accessibilityName, again.label, again.helperText, again.placeholder,
            form.texts(for: first.field).label, item.label, FieldContext(field: item.field, key: item.key, model: form).label,
            section.title, section.description, form.texts(for: section.section).title, form.texts(for: section.section).description,
            group.label, group.helperText, group.items.first?.title, form.texts(for: group.group).label,
            form.itemTitle(0, inGroup: group.group.key), progress.stepTitle, progress.stepDescription,
            form.texts(for: step).title, form.texts(for: step).description,
        ]
        for text in texts {
            #expect(text?.contains("{{x}}") == true, "\(text ?? "nil")")
            #expect(text?.contains("LEAK") == false, "\(text ?? "nil")")
        }
        form.setErrors(["mail": "Bad"])
        let entry = try #require(form.errorGroups.first)
        #expect(entry.title == "Step {{x}}")
        #expect(entry.entries.first?.label == "Mail {{x}}")
    }

    private func rendered(_ form: FormModel) throws -> (SectionContext, GroupContext, ProgressContext) {
        let capture = SlotCapture()
        let components = FormComponents.standard
            .section { context in
                capture.section = context
                return context.content
            }
            .group { context in
                capture.group = context
                return VStack { ForEach(context.items) { $0.content } }
            }
            .progress { context in
                capture.progress = context
                return EmptyView()
            }
        _ = host(FormhausFormContent(model: form).formhausComponents(components))
        return (try #require(capture.section), try #require(capture.group), try #require(capture.progress))
    }
}

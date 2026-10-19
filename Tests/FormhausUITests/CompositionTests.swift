import AppKit
@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI
import Testing

private struct ColorField: View {
    let context: FieldContext

    var body: some View {
        FieldShell(context) {
            HStack {
                Text(context.text)
                LoadingIndicator(visible: context.loading)
            }
            .inputChrome(focused: false, invalid: context.isInvalid, disabled: context.isLocked)
            .overlay(FocusRing(visible: false, radius: 10))
            FieldLabel(context)
            FieldError(text: context.error ?? "")
            Button("Pick") { context.setValue("#000000") }
                .buttonStyle(OptionCardStyle(selected: context.value != nil, invalid: context.isInvalid))
            OptionRow(.checkbox, label: context.label, selected: true)
            ChoiceIndicator(.radio, selected: false)
            Toggle("Bold", isOn: .constant(true)).toggleStyle(CheckboxStyle())
        }
    }
}

private let everyType: JSONValue = [
    "id": "all", "title": "All", "submit": ["label": "Send"],
    "fields": .array(
        ["radio", "multiselect", "select", "autocomplete", "checkbox", "switch", "date", "time", "datetime", "file", "scale", "rating"].map
        { type in
            ["key": .string(type), "type": .string(type), "label": .string(type), "options": [["value": "a", "label": "A"]]]
        }),
]

@Suite("Composing custom fields", .serialized)
@MainActor
struct CompositionTests {
    @Test("custom types and overridden built-ins render from public building blocks")
    func custom() throws {
        _ = NSApplication.shared
        let definition: JSONValue = [
            "id": "c", "title": "C", "submit": ["label": "Send"],
            "fields": [
                ["key": "tint", "type": "x-color", "label": "Tint", "validation": ["required": true]],
                ["key": "note", "type": "text", "label": "Note"], ["key": "bio", "type": "textarea", "label": "Bio"],
            ],
        ]
        let model = FormModel(definition: try FormDefinition(json: definition), initialValues: ["tint": "#5502fb"]) { _, _ in nil }
        var rendered: [String] = []
        let components = FormComponents.standard
            .field("x-color") { ColorField(context: $0) }
            .field("text") { context in
                TextInputField(context).onAppear { rendered.append(context.key) }
            }
            .field("textarea") { TextAreaField($0) }
        let root = VStack {
            FormFields(model: model)
            FormhausFormContent(model: model)
        }
        let host = NSHostingView(rootView: root.formhausComponents(components).frame(width: 400))
        host.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        host.layoutSubtreeIfNeeded()
        #expect(rendered.contains("note"))
        #expect(model.field("tint").value == "#5502fb")
    }

    @Test("a headless renderer composes the built-in field views it registers")
    func headless() throws {
        _ = NSApplication.shared
        let model = FormModel(definition: try FormDefinition(json: everyType)) { _, _ in nil }
        var seen: Set<String> = []
        let components = FormComponents.headless
            .field("radio") { RadioField($0).onAppear { seen.insert("radio") } }
            .field("multiselect") { MultiselectField($0) }
            .field("select") { SelectField($0) }
            .field("autocomplete") { AutocompleteField($0) }
            .field("checkbox") { CheckboxField($0) }
            .field("switch") { SwitchField($0) }
            .field("date") { DateField($0) }
            .field("time") { DateField($0) }
            .field("datetime") { DateField($0) }
            .field("file") { FileField($0) }
            .field("scale") { ScaleField($0) }
            .field("rating") { RatingField($0) }
        let host = NSHostingView(rootView: FormFields(model: model).formhausComponents(components).frame(width: 400))
        host.frame = CGRect(x: 0, y: 0, width: 400, height: 1600)
        host.layoutSubtreeIfNeeded()
        #expect(seen == ["radio"])
    }
}

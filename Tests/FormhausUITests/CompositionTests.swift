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
            FieldLabel(text: context.label, required: context.isRequired)
            FieldError(text: context.error ?? "")
        }
    }
}

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
}

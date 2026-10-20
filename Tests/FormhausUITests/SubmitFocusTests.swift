import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

private let contact: JSONValue = [
    "id": "c", "title": "C", "submit": ["label": "Send"],
    "fields": [
        ["key": "name", "type": "text", "label": "Name"],
        ["key": "email", "type": "email", "label": "Email"],
    ],
]

@MainActor
private struct Hosted {
    let form: FormModel
    let view: NSView
    let window: NSWindow
    let gate = Gate()

    init(_ values: JSONObject = [:], content: (FormModel) -> some View = { FormhausFormContent(model: $0) }) throws {
        let gate = gate
        form = FormModel(definition: try FormDefinition(json: contact), initialValues: values) { _, _ in
            await gate.wait()
            return .rejected(errors: ["email": "Taken"])
        }
        view = host(content(form))
        window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        settle(view)
    }

    var editor: NSTextView? {
        (window.firstResponder as? NSTextView).flatMap { $0.isFieldEditor ? $0 : nil }
    }

    func focus(_ key: String) {
        form.focus(field: key)
        settle(view)
    }

    func startSubmit() async -> Task<Void, Never> {
        let form = form
        let submit = Task { await form.submit() }
        while !form.submitting { await Task.yield() }
        settle(view)
        return submit
    }

    func finish(_ submit: Task<Void, Never>) async {
        gate.open()
        await submit.value
        settle(view)
    }
}

@Suite("Focus while the form is locked", .serialized)
@MainActor
struct SubmitFocusTests {
    @Test("the focused text field keeps focus while a submit runs and after a server error")
    func keepsFocus() async throws {
        let hosted = try Hosted()
        hosted.focus("email")
        #expect(hosted.editor != nil)
        #expect(hosted.form.field("email").hasFocus)
        let submit = await hosted.startSubmit()
        #expect(hosted.form.disabled)
        #expect(hosted.editor != nil)
        let fields = hosted.form.structure.visibleFields
        #expect(!FieldContext(field: try #require(fields.last), model: hosted.form).isLocked)
        #expect(FieldContext(field: try #require(fields.first), model: hosted.form).isLocked)
        await hosted.finish(submit)
        #expect(hosted.form.field("email").error == "Taken")
        #expect(hosted.editor != nil)
    }

    @Test("text typed into the focused field during a submit applies once the form unlocks")
    func heldEdit() async throws {
        let hosted = try Hosted(["email": "ada@x.dev"])
        hosted.focus("email")
        let submit = await hosted.startSubmit()
        let editor = try #require(hosted.editor)
        editor.insertText("m", replacementRange: NSRange(location: editor.string.count, length: 0))
        settle(hosted.view)
        #expect(hosted.form.field("email").value == "ada@x.dev")
        await hosted.finish(submit)
        #expect(hosted.form.field("email").value == "ada@x.devm")
        #expect(editor.string == "ada@x.devm")
    }

    @Test("a field that leaves the screen stops counting as focused")
    func disappearClears() throws {
        let shown = TabChoice()
        let hosted = try Hosted { form in FormVisibility(form: form, shown: shown) }
        hosted.focus("name")
        #expect(hosted.form.field("name").hasFocus)
        shown.tab = 1
        settle(hosted.view)
        #expect(!hosted.form.field("name").hasFocus)
    }
}

private struct FormVisibility: View {
    let form: FormModel
    let shown: TabChoice

    var body: some View {
        if shown.tab == 0 { FormhausFormContent(model: form) } else { Color.clear }
    }
}

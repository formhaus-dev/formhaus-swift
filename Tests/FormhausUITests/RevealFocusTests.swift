import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

@MainActor
private struct RevealHost {
    let form: FormModel
    let view: NSView
    let window: NSWindow

    init(system: Bool, definition: JSONValue = contactReveal, height: CGFloat = 600) throws {
        let form = try revealModel(definition, ["contact": "email"])
        self.form = form
        let components = system ? FormComponents.system : .standard
        let content = NavigationStack { FormhausFormContent(model: form) }
            .formhausComponents(components)
            .formhausBehavior(FormBehavior(errorSummary: false, conditionalReveal: true))
        view = host(content, height: height)
        window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        settle(view)
    }

    var editor: NSTextView? {
        (window.firstResponder as? NSTextView).flatMap { $0.isFieldEditor ? $0 : nil }
    }

    var scrollOffset: CGFloat? { offset(in: view) }

    func focus(_ key: String) {
        form.focus(field: key)
        settle(view)
        settle(view)
    }

    private func offset(in view: NSView) -> CGFloat? {
        if let scroll = view as? NSScrollView { return scroll.contentView.bounds.origin.y }
        return view.subviews.lazy.compactMap(offset(in:)).first
    }
}

extension SubmitFocusTests {
    @Suite("Focus in revealed fields")
    @MainActor
    struct Reveals {
        @Test("a focused revealed field does not count as focus on its choice", arguments: [false, true])
        func nestedFocus(system: Bool) throws {
            let hosted = try RevealHost(system: system)
            hosted.focus("email")
            #expect(hosted.editor != nil)
            #expect(hosted.form.field("email").hasFocus)
            #expect(!hosted.form.field("contact").hasFocus)
        }

        @Test("focus on a choice never lands in its revealed field")
        func choiceFocus() throws {
            let hosted = try RevealHost(system: false)
            hosted.focus("contact")
            #expect(hosted.editor == nil)
            #expect(!hosted.form.field("email").hasFocus)
        }

        @Test("a focused revealed field keeps the keyboard while the form is locked", arguments: [false, true])
        func lockedForm(system: Bool) throws {
            let hosted = try RevealHost(system: system)
            hosted.focus("email")
            hosted.form.loading = true
            settle(hosted.view)
            #expect(hosted.form.disabled)
            #expect(hosted.editor != nil)
            #expect(hosted.form.field("email").hasFocus)
        }
    }
}

extension StepScrollTests {
    @Suite("Scrolling to revealed fields")
    @MainActor
    struct Reveals {
        @Test("a focus request scrolls the system list to a revealed field")
        func systemScroll() throws {
            var fields = contactReveal["fields"]?.arrayValue ?? []
            fields += (0..<30).map { ["key": .string("f\($0)"), "type": "text", "label": .string("Field \($0)")] }
            let definition: JSONValue = ["id": "long", "title": "Long", "submit": ["label": "Send"], "fields": .array(fields)]
            let hosted = try RevealHost(system: true, definition: definition, height: 400)
            hosted.focus("f29")
            let bottom = try #require(hosted.scrollOffset)
            hosted.focus("email")
            let revealed = try #require(hosted.scrollOffset)
            #expect(bottom > 0)
            #expect(revealed < bottom)
        }

        @Test("a focus request scrolls the system list to a field revealed inside a section")
        func systemSectionScroll() throws {
            var fields: [JSONValue] = (0..<30).map { ["key": .string("f\($0)"), "type": "text", "label": .string("Field \($0)")] }
            fields.append(["key": "about", "type": "section", "title": "About", "fields": contactReveal["fields"] ?? []])
            let definition: JSONValue = ["id": "long", "title": "Long", "submit": ["label": "Send"], "fields": .array(fields)]
            let hosted = try RevealHost(system: true, definition: definition, height: 400)
            let top = try #require(hosted.scrollOffset)
            hosted.focus("email")
            #expect(try #require(hosted.scrollOffset) > top)
        }
    }
}

import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

@MainActor
private func stepsForm(_ values: JSONObject = JSONObject()) throws -> FormModel {
    let json: JSONValue = [
        "id": "s", "title": "S", "submit": ["label": "Send"],
        "steps": [
            ["id": "one", "title": "One", "fields": [["key": "a", "type": "text", "label": "A", "validation": ["required": true]]]],
            ["id": "two", "title": "Two", "fields": [["key": "b", "type": "text", "label": "B"]]],
        ],
    ]
    return FormModel(definition: try FormDefinition(json: json), initialValues: values) { _, _ in nil }
}

@Suite("Step changes scroll to the top", .serialized)
@MainActor
struct StepScrollTests {
    @Test("a step change targets the screen top by default and the form top on request")
    func stepTargets() async throws {
        let form = try stepsForm(["a": "x"])
        form.start()
        let before = ScrollTrigger(form)
        await form.next()
        let after = ScrollTrigger(form)
        #expect(form.structure.currentStep?.id == "two")
        #expect(FormBehavior().stepScroll == .screenTop)
        #expect(ScrollTarget.resolve(from: before, to: after, mode: .screenTop) == .screenTop)
        #expect(ScrollTarget.resolve(from: before, to: after, mode: .formTop) == .formTop)
        #expect(ScrollTarget.resolve(from: after, to: after, mode: .screenTop) == nil)
    }

    @Test("focus on an invalid field wins over the top on a step change")
    func errorWins() async throws {
        let form = try stepsForm(["a": "x"])
        form.start()
        await form.next()
        form.setValue("", forKey: "a")
        let before = ScrollTrigger(form)
        await form.submit()
        let after = ScrollTrigger(form)
        #expect(form.structure.currentStep?.id == "one")
        #expect(ScrollTarget.resolve(from: before, to: after, mode: .screenTop) == .field("a"))
        #expect(ScrollTarget.resolve(from: before, to: after, mode: .formTop) == .field("a"))
    }

    @Test("FormhausFormContent asks the owning scroll view for its top on Next and Back")
    func ownedRequest() async throws {
        let form = try stepsForm(["a": "x"])
        let requests = TopRequests()
        let view = host(FormhausFormContent(model: form).environment(\.formhausTopRequests, requests))
        await form.next()
        settle(view)
        #expect(requests.issued == 1)
        await form.back()
        settle(view)
        #expect(requests.issued == 2)
    }

    @Test("an error focus on a step change asks for no top")
    func ownedErrorFocus() async throws {
        let form = try stepsForm(["a": "x"])
        let requests = TopRequests()
        let view = host(FormhausFormContent(model: form).environment(\.formhausTopRequests, requests))
        await form.next()
        settle(view)
        form.setValue("", forKey: "a")
        await form.submit()
        settle(view)
        #expect(form.structure.currentStep?.id == "one")
        #expect(requests.issued == 1)
    }

    @Test("the form-top option keeps the scroll inside the form")
    func formTopOption() async throws {
        let form = try stepsForm(["a": "x"])
        let requests = TopRequests()
        let content = FormhausFormContent(model: form).formhausBehavior(stepScroll: .formTop)
        let view = host(content.environment(\.formhausTopRequests, requests))
        await form.next()
        settle(view)
        #expect(requests.issued == 0)
    }

    @Test("a hosted form scrolls the host scroll view back to its very top")
    func hostedScreenTop() async throws {
        let form = try stepsForm(["a": "x"])
        #expect(try await hostedOffset(form, page(form, .screenTop)) < 1)
    }

    @Test("the form-top option scrolls a hosted form only to its own top")
    func hostedFormTop() async throws {
        let form = try stepsForm(["a": "x"])
        let offset = try await hostedOffset(form, page(form, .formTop))
        #expect(offset > 850 && offset < 950)
    }

    @Test("FormhausForm scrolls its own scroll view back to its very top")
    func ownedScreenTop() async throws {
        let form = try stepsForm(["a": "x"])
        #expect(try await hostedOffset(form, FormhausForm(model: form), height: 120, start: 60) < 1)
    }
}

@MainActor
private func page(_ form: FormModel, _ mode: StepScroll) -> some View {
    ScrollView {
        VStack(spacing: 0) {
            Color.gray.frame(height: 900)
            FormhausFormContent(model: form).formhausBehavior(stepScroll: mode)
            Color.gray.frame(height: 900)
        }
    }
}

@MainActor
private func hostedOffset(
    _ form: FormModel, _ page: some View, height: CGFloat = 400, start: CGFloat = 1200
) async throws -> CGFloat {
    let view = host(page, height: height)
    let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = view
    settle(view)
    #expect(!window.isVisible && !window.isKeyWindow)
    let scroller = try #require(scrollView(in: view))
    scroller.contentView.scroll(to: CGPoint(x: 0, y: start))
    scroller.reflectScrolledClipView(scroller.contentView)
    settle(view)
    #expect(scroller.contentView.bounds.origin.y == start)
    await form.next()
    var offset = scroller.contentView.bounds.origin.y
    for _ in 0..<40 {
        settle(view)
        let next = scroller.contentView.bounds.origin.y
        if next == offset, next != start { break }
        offset = next
    }
    return offset
}
@MainActor
private func scrollView(in view: NSView) -> NSScrollView? {
    if let scroll = view as? NSScrollView { return scroll }
    return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
}

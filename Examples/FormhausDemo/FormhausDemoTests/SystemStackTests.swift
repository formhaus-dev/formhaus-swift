import FormhausCore
import FormhausUI
import SwiftUI
import Testing
import UIKit

@testable import FormhausDemo

private let threeSteps: JSONValue = [
    "id": "p", "title": "P", "submit": ["label": "Send"],
    "steps": [
        ["id": "a", "title": "Alpha", "fields": [["key": "x", "type": "text", "label": "X", "validation": ["required": true]]]],
        ["id": "b", "title": "Bravo", "fields": [["key": "y", "type": "text", "label": "Y"]]],
        ["id": "c", "title": "Charlie", "fields": [["key": "z", "type": "text", "label": "Z"]]],
    ],
]

@MainActor
@Observable
private final class StackBox {
    var model: FormModel
    var system = true

    init(_ model: FormModel) {
        self.model = model
    }
}

private struct StackHost: View {
    let box: StackBox

    var body: some View {
        NavigationStack {
            FormhausFormContent(model: box.model)
        }
        .formhausComponents(box.system ? .system : .standard)
    }
}

@MainActor
private final class Stage {
    let box: StackBox
    let window: UIWindow
    let controller: UIHostingController<StackHost>

    init(_ model: FormModel) {
        box = StackBox(model)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        controller = UIHostingController(rootView: StackHost(box: box))
        window.rootViewController = controller
        window.makeKeyAndVisible()
    }

    var navigation: UINavigationController? { find(controller) }

    var depth: Int { navigation?.viewControllers.count ?? 0 }

    func close() {
        window.isHidden = true
        window.rootViewController = nil
    }

    private func find(_ controller: UIViewController) -> UINavigationController? {
        if let navigation = controller as? UINavigationController { return navigation }
        return controller.children.lazy.compactMap { self.find($0) }.first
    }
}

@MainActor
private func stepsModel(values: JSONObject = ["x": "1"], delay: Bool = false) throws -> FormModel {
    var options = FormEngineOptions()
    if delay {
        options.onStepValidate = { _, _ in
            try await Task.sleep(for: .milliseconds(1200))
            return nil
        }
    }
    return FormModel(definition: try FormDefinition(json: threeSteps), initialValues: values, engineOptions: options) { _, _ in .ok }
}

@MainActor
private func settle(_ milliseconds: Int = 900) async {
    try? await Task.sleep(for: .milliseconds(milliseconds))
}

@MainActor
private func spoken(_ view: UIView) -> [String] {
    var labels: [String] = []
    func walk(_ element: NSObject) {
        if element.isAccessibilityElement, let label = element.accessibilityLabel, !label.isEmpty {
            labels.append(label)
            return
        }
        if let children = element.accessibilityElements as? [NSObject] {
            children.forEach(walk)
            return
        }
        (element as? UIView)?.subviews.forEach(walk)
    }
    walk(view)
    return labels
}

@MainActor
private func responder(_ view: UIView) -> UIView? {
    if view.isFirstResponder { return view }
    return view.subviews.lazy.compactMap { responder($0) }.first
}

@Suite("System step stack", .serialized)
@MainActor
struct SystemStackTests {
    @Test("each pushed page shows its own step")
    func backStack() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        await settle()
        await model.next()
        await settle()
        await model.next()
        await settle()
        let pages = stage.navigation?.viewControllers ?? []
        #expect(pages.count == 3)
        #expect(pages.map(\.navigationItem.title) == ["Alpha", "Bravo", "Charlie"])
        for (index, page) in pages.enumerated().dropFirst() {
            page.view.frame = stage.window.bounds
            page.view.layoutIfNeeded()
            let fields = spoken(page.view).filter { ["X", "Y", "Z"].contains($0) }
            #expect(fields == [["X"], ["Y"], ["Z"]][index], "level \(index): \(fields)")
        }
        stage.navigation?.popViewController(animated: false)
        await settle()
        let middle = spoken(stage.window).filter { ["X", "Y", "Z"].contains($0) }
        #expect(middle == ["Y"])
        #expect(model.structure.currentStep?.id == "b")
        stage.close()
    }

    @Test("replacing the model pops its pushed steps")
    func modelReplaced() async throws {
        let stage = Stage(try stepsModel())
        await settle()
        await stage.box.model.next()
        await stage.box.model.next()
        await settle()
        #expect(stage.depth == 3)
        stage.box.model = try stepsModel(values: [:])
        await settle()
        #expect(stage.depth == 1)
        stage.close()
    }

    @Test("switching to another set pops the pushed steps")
    func styleSwitched() async throws {
        let stage = Stage(try stepsModel())
        await settle()
        await stage.box.model.next()
        await settle()
        #expect(stage.depth == 2)
        stage.box.system = false
        await settle()
        #expect(stage.depth == 1)
        stage.close()
    }

    @Test("focusing a field on an earlier step pops back and focuses it")
    func focusAfterJumpBack() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        await settle()
        await model.next()
        await settle()
        await model.next()
        await settle()
        model.focus(field: "x")
        await settle(1500)
        #expect(stage.depth == 1)
        #expect(responder(stage.window) is UITextField)
        stage.close()
    }

    @Test("back is hidden while a step validates")
    func backDuringValidation() async throws {
        let model = try stepsModel(delay: true)
        let stage = Stage(model)
        await settle()
        await model.next()
        await settle()
        let pending = Task { await model.next() }
        await settle(300)
        #expect(model.stepValidating)
        #expect(stage.navigation?.topViewController?.navigationItem.hidesBackButton == true)
        await pending.value
        await settle()
        #expect(stage.depth == 3)
        stage.close()
    }

    @Test("a reset pops back to the first step")
    func reset() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        await settle()
        await model.next()
        await model.next()
        await settle()
        model.engine.reset()
        await settle()
        #expect(stage.depth == 1)
        stage.close()
    }
}

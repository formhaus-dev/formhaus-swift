import FormhausCore
import FormhausUI
import SwiftUI
import Testing
import UIKit

@testable import FormhausDemo

let threeSteps: JSONValue = [
    "id": "p", "title": "P", "submit": ["label": "Send"],
    "steps": [
        ["id": "a", "title": "Alpha", "fields": [["key": "x", "type": "text", "label": "X", "validation": ["required": true]]]],
        ["id": "b", "title": "Bravo", "fields": [["key": "y", "type": "text", "label": "Y"]]],
        ["id": "c", "title": "Charlie", "fields": [["key": "z", "type": "text", "label": "Z"]]],
    ],
]

@MainActor
@Observable
final class StackBox {
    var model: FormModel
    var system = true
    let deep: Bool

    init(_ model: FormModel, deep: Bool) {
        self.model = model
        self.deep = deep
    }
}

struct StackHost: View {
    let box: StackBox

    var body: some View {
        NavigationStack {
            if box.deep {
                Text(verbatim: "Home").navigationDestination(isPresented: .constant(true)) { StackForm(box: box) }
            } else {
                StackForm(box: box)
            }
        }
    }
}

private struct StackForm: View {
    let box: StackBox

    var body: some View {
        FormhausFormContent(model: box.model).formhausComponents(box.system ? .system : .standard)
    }
}

@MainActor
final class Stage {
    let box: StackBox
    let window: UIWindow
    let controller: UIHostingController<StackHost>

    init(_ model: FormModel, deep: Bool = false) {
        enableAccessibilityAutomation()
        box = StackBox(model, deep: deep)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        controller = UIHostingController(rootView: StackHost(box: box))
        window.rootViewController = controller
        window.makeKeyAndVisible()
    }

    var navigation: UINavigationController? { find(controller) }

    var depth: Int { navigation?.viewControllers.count ?? 0 }

    var fields: [String] {
        axLabels(window).map { String($0.prefix(while: \.isLetter)) }.filter { ["X", "Y", "Z", "Secret"].contains($0) }
    }

    var hostBackHidden: Bool { navigation?.topViewController?.navigationItem.hidesBackButton ?? false }

    var barBack: AXNode? {
        axTree(window).first { node in
            node.bar && node.label == "Back" && !(node.element.map { "\(type(of: $0))" } ?? "").contains("BackButton")
        }
    }

    func tapBack() -> Bool {
        barBack?.element?.accessibilityActivate() ?? false
    }

    func close() {
        window.isHidden = true
        window.rootViewController = nil
    }

    func find(_ controller: UIViewController) -> UINavigationController? {
        if let navigation = controller as? UINavigationController { return navigation }
        return controller.children.lazy.compactMap { self.find($0) }.first
    }
}

@MainActor
func stepsModel(values: JSONObject = ["x": "1"], delay: Bool = false, options base: FormEngineOptions = FormEngineOptions()) throws
    -> FormModel
{
    var options = base
    if delay {
        options.onStepValidate = { _, _ in
            try await Task.sleep(for: .milliseconds(2500))
            return nil
        }
    }
    return FormModel(definition: try FormDefinition(json: threeSteps), initialValues: values, engineOptions: options) { _, _ in .ok }
}

@MainActor
func settle(_ milliseconds: Int = 900) async {
    try? await Task.sleep(for: .milliseconds(milliseconds))
}

@MainActor
func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<30 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(100))
    }
    return condition()
}

@MainActor
func responder(_ view: UIView) -> UIView? {
    if view.isFirstResponder { return view }
    return view.subviews.lazy.compactMap { responder($0) }.first
}

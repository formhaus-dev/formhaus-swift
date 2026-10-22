import SwiftUI
import UIKit

@testable import FormhausDemo

struct AXNode {
    let label: String
    let value: String
    let hint: String
    let traits: UIAccessibilityTraits
    let frame: CGRect
    var cell: CGRect?
    var bar = false
    weak var element: NSObject?

    var isInteractive: Bool { traits.contains(.button) || traits.contains(.adjustable) }
    var isSwitch: Bool { traits.contains(.toggleButton) }
}

@MainActor
private let automation: Void = {
    guard let handle = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW), let symbol = dlsym(handle, "_AXSSetAutomationEnabled")
    else { return }
    typealias Setter = @convention(c) (Int32) -> Void
    unsafeBitCast(symbol, to: Setter.self)(1)
}()

@MainActor
func enableAccessibilityAutomation() {
    automation
}

@MainActor
func axLabels(_ view: UIView) -> [String] {
    axTree(view).map(\.label).filter { !$0.isEmpty }
}

@MainActor
func axTree(_ view: UIView) -> [AXNode] {
    var nodes: [AXNode] = []
    walk(view, into: &nodes)
    return nodes
}

@MainActor
func axNodes(_ view: some View, size: CGSize = CGSize(width: 393, height: 2400)) async -> [AXNode] {
    enableAccessibilityAutomation()
    UITextField.appearance().inputView = UIView(frame: .zero)
    UITextField.appearance().inputAccessoryView = nil
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
    window.frame = CGRect(origin: .zero, size: size)
    let controller = UIHostingController(rootView: view)
    window.rootViewController = controller
    window.isHidden = false
    for _ in 0..<10 {
        try? await Task.sleep(for: .milliseconds(100))
        window.layoutIfNeeded()
    }
    var nodes: [AXNode] = []
    walk(controller.view, into: &nodes)
    window.isHidden = true
    window.rootViewController = nil
    return nodes
}

@MainActor
private func walk(_ element: NSObject, cell: CGRect? = nil, bar: Bool = false, into nodes: inout [AXNode]) {
    let cell = element is UICollectionViewCell ? element.accessibilityFrame : cell
    let bar = bar || element is UINavigationBar
    if element.isAccessibilityElement {
        nodes.append(
            AXNode(
                label: element.accessibilityLabel ?? "", value: element.accessibilityValue ?? "",
                hint: element.accessibilityHint ?? "", traits: element.accessibilityTraits, frame: element.accessibilityFrame,
                cell: cell, bar: bar, element: element))
        return
    }
    for child in children(of: element) { walk(child, cell: cell, bar: bar, into: &nodes) }
}

@MainActor
func accessibilityIdentifiers(_ element: NSObject) -> [String] {
    let selector = NSSelectorFromString("accessibilityIdentifier")
    let own = element.responds(to: selector) ? element.perform(selector)?.takeUnretainedValue() as? String : nil
    let found = own.map { $0.isEmpty ? [] : [$0] } ?? []
    return found + children(of: element).flatMap(accessibilityIdentifiers)
}

@MainActor
private func children(of element: NSObject) -> [NSObject] {
    if let children = element.accessibilityElements as? [NSObject] { return children }
    let count = element.accessibilityElementCount()
    if count != NSNotFound, count > 0 {
        return (0..<count).compactMap { element.accessibilityElement(at: $0) as? NSObject }
    }
    return (element as? UIView)?.subviews ?? []
}

extension [AXNode] {
    func target(_ node: AXNode) -> CGRect {
        guard let cell = node.cell, filter({ $0.isInteractive && $0.cell == cell }).count == 1 else { return node.frame }
        return cell
    }
}

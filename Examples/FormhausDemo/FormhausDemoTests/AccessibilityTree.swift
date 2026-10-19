import SwiftUI
import UIKit

struct AXNode {
    let label: String
    let value: String
    let hint: String
    let traits: UIAccessibilityTraits
    let frame: CGRect
    var cell: CGRect?

    var isInteractive: Bool { traits.contains(.button) || traits.contains(.adjustable) }
}

@MainActor
private let automation: Void = {
    guard let handle = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW), let symbol = dlsym(handle, "_AXSSetAutomationEnabled")
    else { return }
    typealias Setter = @convention(c) (Int32) -> Void
    unsafeBitCast(symbol, to: Setter.self)(1)
}()

@MainActor
func axNodes(_ view: some View, size: CGSize = CGSize(width: 393, height: 2400)) async -> [AXNode] {
    automation
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
    window.frame = CGRect(origin: .zero, size: size)
    let controller = UIHostingController(rootView: view)
    window.rootViewController = controller
    window.isHidden = false
    for _ in 0..<6 {
        try? await Task.sleep(for: .milliseconds(60))
        window.layoutIfNeeded()
    }
    var nodes: [AXNode] = []
    walk(controller.view, into: &nodes)
    window.isHidden = true
    window.rootViewController = nil
    return nodes
}

@MainActor
private func walk(_ element: NSObject, cell: CGRect? = nil, into nodes: inout [AXNode]) {
    let cell = element is UICollectionViewCell ? element.accessibilityFrame : cell
    if element.isAccessibilityElement {
        nodes.append(
            AXNode(
                label: element.accessibilityLabel ?? "", value: element.accessibilityValue ?? "",
                hint: element.accessibilityHint ?? "", traits: element.accessibilityTraits, frame: element.accessibilityFrame,
                cell: cell))
        return
    }
    for child in children(of: element) { walk(child, cell: cell, into: &nodes) }
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

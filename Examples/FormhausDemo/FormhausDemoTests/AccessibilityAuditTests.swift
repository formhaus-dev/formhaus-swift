import FormhausCore
import FormhausUI
import SwiftUI
import Testing
import UIKit

@testable import FormhausDemo

@Suite("Accessibility audit", .serialized)
@MainActor
struct AccessibilityAuditTests {
    @Test("interactive elements are at least 44 by 44 points and do not overlap", arguments: DemoStyle.allCases)
    func hitTargets(style: DemoStyle) async throws {
        for audit in auditCases {
            let all = await axNodes(auditView(try await audit.build(), style))
            let nodes = all.filter { $0.isInteractive && !$0.bar }
            for node in nodes {
                let target = all.target(node)
                if node.isSwitch, target.height >= 28 { continue }
                #expect(
                    target.width >= 43.5 && target.height >= 43.5, "\(style) \(audit.name): \(node.label) \(target) \(node.traits.rawValue)"
                )
            }
            for (index, node) in nodes.enumerated() {
                for other in nodes[(index + 1)...] where overlaps(node.frame, other.frame) {
                    Issue.record("\(style) \(audit.name): \(node.label) \(node.frame) overlaps \(other.label) \(other.frame)")
                }
            }
        }
    }

    @Test("interactive elements have labels, required and error states are spoken in order", arguments: DemoStyle.allCases)
    func voiceOver(style: DemoStyle) async throws {
        for audit in auditCases {
            let model = try await audit.build()
            let nodes = await axNodes(auditView(model, style))
            for node in nodes where node.isInteractive {
                #expect(!node.label.trimmingCharacters(in: .whitespaces).isEmpty, "\(style) \(audit.name): unlabelled \(node.frame)")
            }
            for field in model.structure.visibleFields where !field.isGroup && field.type != "hidden" {
                checkField(field, model: model, nodes: nodes, name: "\(style) \(audit.name)")
            }
        }
    }

    @Test("accessibility sizes fit the width without overlapping text", arguments: DemoStyle.allCases)
    func dynamicType(style: DemoStyle) async throws {
        let width: CGFloat = 393
        for audit in auditCases {
            let model = try await audit.build()
            let title = model.structure.currentStep?.title
            let nodes = await axNodes(auditView(model, style, typeSize: .accessibility5), size: CGSize(width: width, height: 6000))
            for node in nodes where !node.label.isEmpty {
                #expect(node.frame.minX >= -0.5 && node.frame.maxX <= width + 0.5, "\(style) \(audit.name): \(node.label) \(node.frame)")
            }
            let text = nodes.filter { !$0.isInteractive && !$0.label.isEmpty && !$0.bar && !(style == .system && $0.label == title) }
            for (index, node) in text.enumerated() {
                for other in text[(index + 1)...] where overlaps(node.frame, other.frame) {
                    Issue.record("\(style) \(audit.name): \(node.label) \(node.frame) overlaps \(other.label) \(other.frame)")
                }
            }
        }
    }

    private func checkField(_ field: FormField, model: FormModel, nodes: [AXNode], name: String) {
        let label = field.label ?? ""
        guard !label.isEmpty, let first = nodes.firstIndex(where: { $0.spoken.contains(label) }) else {
            Issue.record("\(name): \(field.key) is not spoken")
            return
        }
        let required = model.text(forLabel: "required")
        if FieldContext(field: field, model: model).isRequired {
            #expect(nodes.contains { $0.spoken.contains(label) && $0.spoken.contains(required) }, "\(name): \(field.key) required")
        }
        if let error = model.field(field.key).error, !error.isEmpty {
            let spoken = nodes.indices.filter { nodes[$0].spoken.contains(error) }
            #expect(spoken.contains { $0 >= first }, "\(name): \(field.key) error is not after its label")
        }
    }
}

extension AXNode {
    var spoken: String { [label, value, hint].joined(separator: " ") }
}

func overlaps(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
    let shared = lhs.intersection(rhs)
    guard !shared.isNull, shared.width > 1, shared.height > 1 else { return false }
    return !(lhs.insetBy(dx: -1, dy: -1).contains(rhs) || rhs.insetBy(dx: -1, dy: -1).contains(lhs))
}

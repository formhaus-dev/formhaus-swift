@_spi(Renderer) import FormhausCore
import SwiftUI

struct FieldReveal {
    let option: FieldOption
    let nodes: [RevealedNode]
}

struct RevealedNode {
    let node: FormNode
    var reveals: [FieldReveal] = []

    var id: Int { node.nodeID }
}

struct RevealPlan {
    let revision: Int
    private var parents: [Int: (parent: Int, option: Int)] = [:]
    private var options: [Int: [Int]] = [:]

    init(_ definition: FormDefinition, revision: Int) {
        self.revision = revision
        let tops = definition.isMultiStep ? (definition.steps ?? []).map(\.fields) : [definition.fields ?? []]
        let lists = tops + tops.flatMap { $0.compactMap(\.section).filter { !$0.isMatrix }.map(\.fields) }
        var found: [Int: Set<Int>] = [:]
        for nodes in lists {
            for (index, target) in revealTargets(nodes).enumerated() {
                guard let target else { continue }
                let parent = nodes[target.parent].nodeID
                parents[nodes[index].nodeID] = (parent, target.option)
                found[parent, default: []].insert(target.option)
            }
        }
        options = found.mapValues { $0.sorted() }
    }

    func layout(_ nodes: [FormNode], can: (FormField) -> Bool) -> [RevealedNode] {
        let shown = Dictionary(nodes.compactMap(\.field).map { ($0.nodeID, $0) }) { first, _ in first }
        var children: [Int: [Int: [FormNode]]] = [:]
        var top: [FormNode] = []
        for node in nodes {
            if let (parent, option) = parents[node.nodeID], let field = shown[parent], can(field) {
                children[parent, default: [:]][option, default: []].append(node)
            } else {
                top.append(node)
            }
        }
        func place(_ node: FormNode) -> RevealedNode {
            guard let field = node.field, let indexes = options[field.nodeID], can(field), let choices = field.options else {
                return RevealedNode(node: node)
            }
            let reveals = indexes.filter(choices.indices.contains).map { index in
                FieldReveal(option: choices[index], nodes: (children[field.nodeID]?[index] ?? []).map(place))
            }
            return RevealedNode(node: node, reveals: reveals)
        }
        return top.map(place)
    }
}

extension FormModel {
    func revealLayout(_ nodes: [FormNode], can: ((FormField) -> Bool)?) -> [RevealedNode] {
        guard let can else { return nodes.map { RevealedNode(node: $0) } }
        let revision = engine.definitionRevision
        let plan = revealPlan.flatMap { $0.revision == revision ? $0 : nil } ?? RevealPlan(definition, revision: revision)
        revealPlan = plan
        return plan.layout(nodes, can: can)
    }
}

extension FormComponents {
    func revealable(_ behavior: FormBehavior) -> ((FormField) -> Bool)? {
        guard behavior.conditionalReveal else { return nil }
        return { field in
            fields[field.type] == nil && (system ? isInlineChoice(field, limit: behavior.inlineChoiceLimit) : builtIns)
        }
    }
}

struct RevealPlacement: DynamicProperty {
    @Environment(\.formhausComponents) private var components
    @Environment(\.formhausBehavior) private var behavior

    @MainActor
    func callAsFunction(_ nodes: [FormNode], _ model: FormModel) -> [RevealedNode] {
        model.revealLayout(nodes, can: components.revealable(behavior))
    }
}

extension FieldReveal {
    func contains(_ key: String) -> Bool {
        nodes.contains { $0.node.field?.key == key || $0.reveals.contains { $0.contains(key) } }
    }
}

func revealRowID(_ key: String, _ option: FieldOption) -> String {
    "\(key)/reveal/\(option.value ?? "")"
}

struct RevealScroll {
    let choice: String
    let row: String
    let anchor: UnitPoint?
}

func revealRow(of key: String, in placed: [RevealedNode], sections: ([FormNode]) -> [RevealedNode]) -> RevealScroll? {
    for node in placed.flatMap({ $0.node.section.map { sections($0.fields) } ?? [$0] }) {
        guard let field = node.node.field, let reveal = node.reveals.first(where: { $0.contains(key) }) else { continue }
        let count = reveal.nodes.count
        let index = reveal.nodes.firstIndex { $0.node.field?.key == key || $0.reveals.contains { $0.contains(key) } } ?? 0
        let anchor = count > 1 ? UnitPoint(x: 0.5, y: Double(index + 1) / Double(count)) : nil
        return RevealScroll(choice: field.key, row: revealRowID(field.key, reveal.option), anchor: anchor)
    }
    return nil
}

extension FieldContext {
    func openReveal(_ option: FieldOption) -> FieldReveal? {
        reveals.first { $0.option == option && !$0.nodes.isEmpty }
    }
}

struct RevealBlock: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.formhausComponents) private var components
    let reveal: FieldReveal
    let model: FormModel

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacing.s10) {
            ForEach(reveal.nodes, id: \.id) { FormNodeView(node: $0.node, model: model, reveals: $0.reveals) }
        }
        .padding(.vertical, tokens.spacing.s3)
        .padding(.leading, tokens.spacing.s10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            Rectangle().fill(tokens.colors.border).frame(width: tokens.controls.revealLine).accessibilityHidden(true)
        }
        .padding(.leading, components.system ? 0 : tokens.spacing.s6 + (tokens.controls.indicator - tokens.controls.revealLine) / 2)
        .environment(\.formhausNested, true)
        .environment(\.formhausSectionRows, false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: reveal.option.label ?? reveal.option.value ?? ""))
    }
}

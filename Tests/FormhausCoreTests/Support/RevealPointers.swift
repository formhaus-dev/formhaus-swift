@testable import FormhausCore

func revealPointers(_ json: JSONValue) -> JSONValue {
    let definition = FormDefinition(unchecked: json.objectValue ?? JSONObject())
    let tops: [(String, [FormNode])] =
        definition.isMultiStep
        ? (definition.steps ?? []).enumerated().map { ("/steps/\($0.offset)/fields", $0.element.fields) }
        : [("/fields", definition.fields ?? [])]
    let lists = tops.flatMap { path, nodes in
        [(path, nodes)]
            + nodes.enumerated().compactMap { index, node in
                node.section.flatMap { $0.isMatrix ? nil : ("\(path)/\(index)/fields", $0.fields) }
            }
    }
    var found = JSONObject()
    for (path, nodes) in lists {
        for (index, target) in revealTargets(nodes).enumerated() {
            guard let target else { continue }
            found["\(path)/\(index)"] = ["parent": .string("\(path)/\(target.parent)"), "option": .number(Double(target.option))]
        }
    }
    return .object(found)
}

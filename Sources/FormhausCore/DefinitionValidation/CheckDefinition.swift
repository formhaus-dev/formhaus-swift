public struct CheckDefinitionOptions: Sendable {
    public var validators: Set<String>?

    public init(validators: Set<String>? = nil) {
        self.validators = validators
    }
}

func definitionIssues(_ input: JSONValue, warnings: Bool, validators: Set<String>? = nil) -> [DefinitionIssue] {
    let shape = shapeIssues(input)
    guard shape.isEmpty, let root = input.objectValue else { return shape }
    let context = CheckContext(FormDefinition(unchecked: root), validators: validators)
    return metaIssues(root) + structureIssues(context) + conditionIssues(context) + fieldIssues(context)
        + sourceIssues(context) + graphIssues(context) + (warnings ? definitionWarnings(context) : [])
}

public func checkDefinition(_ input: JSONValue, options: CheckDefinitionOptions = CheckDefinitionOptions()) -> [DefinitionIssue] {
    definitionIssues(input, warnings: true, validators: options.validators)
}

public func validateDefinition(_ input: JSONValue) -> [String] {
    checkDefinition(input).map(\.message)
}

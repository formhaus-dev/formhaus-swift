public struct TestIdTarget: Sendable, Hashable {
    public enum Kind: String, Sendable {
        case form
        case field
        case option
        case submit
        case next
        case back
        case cancel
        case summary
    }

    public let kind: Kind
    public let definitionId: String
    public let key: String?
    public let value: String?

    public init(kind: Kind, definitionId: String, key: String? = nil, value: String? = nil) {
        self.kind = kind
        self.definitionId = definitionId
        self.key = key
        self.value = value
    }

    public var defaultId: String {
        "\(definitionId).\(key ?? kind.rawValue)" + (value.map { ".\($0)" } ?? "")
    }
}

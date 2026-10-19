public struct MessageKey: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }

    public var description: String { rawValue }

    public static func == (lhs: MessageKey, rhs: MessageKey) -> Bool {
        sameText(lhs.rawValue, rhs.rawValue)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(JSKey(rawValue))
    }
}

extension MessageKey {
    public static let required = MessageKey(rawValue: "required")
    public static let minLength = MessageKey(rawValue: "minLength")
    public static let maxLength = MessageKey(rawValue: "maxLength")
    public static let minItems = MessageKey(rawValue: "minItems")
    public static let maxItems = MessageKey(rawValue: "maxItems")
    public static let min = MessageKey(rawValue: "min")
    public static let max = MessageKey(rawValue: "max")
    public static let pattern = MessageKey(rawValue: "pattern")
    public static let matchField = MessageKey(rawValue: "matchField")
    public static let email = MessageKey(rawValue: "email")
    public static let number = MessageKey(rawValue: "number")
    public static let date = MessageKey(rawValue: "date")
    public static let datetime = MessageKey(rawValue: "datetime")
    public static let time = MessageKey(rawValue: "time")
    public static let option = MessageKey(rawValue: "option")
    public static let options = MessageKey(rawValue: "options")
    public static let boolean = MessageKey(rawValue: "boolean")
    public static let string = MessageKey(rawValue: "string")
    public static let file = MessageKey(rawValue: "file")
    public static let value = MessageKey(rawValue: "value")
    public static let hidden = MessageKey(rawValue: "hidden")
}

struct OptionIndex: Sendable {
    private enum Key: Hashable {
        case text(JSKey)
        case number(Double)
        case flag(Bool)

        init?(_ value: JSONValue?) {
            switch value {
            case .string(let text)?: self = .text(JSKey(text))
            case .number(let number)?: self = .number(number)
            case .bool(let flag)?: self = .flag(flag)
            default: return nil
            }
        }
    }

    private var positions: [Key: Int] = [:]

    init(_ options: [FieldOption]) {
        for (position, option) in options.enumerated() {
            if let key = Key(option.json["value"]), positions[key] == nil { positions[key] = position }
        }
    }

    func position(of value: JSONValue) -> Int? {
        Key(value).flatMap { positions[$0] }
    }
}

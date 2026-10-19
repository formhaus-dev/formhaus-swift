import Foundation

public enum JSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object(JSONObject)

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var objectValue: JSONObject? {
        if case .object(let value) = self { return value }
        return nil
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public subscript(key: String) -> JSONValue? {
        objectValue?[key]
    }

    var isTruthy: Bool {
        switch self {
        case .null: false
        case .bool(let value): value
        case .number(let value): value != 0 && !value.isNaN
        case .string(let value): !value.isEmpty
        case .array, .object: true
        }
    }

    var typeName: String {
        switch self {
        case .null, .array, .object: "object"
        case .bool: "boolean"
        case .number: "number"
        case .string: "string"
        }
    }

    var isInteger: Bool {
        numberValue?.isInteger == true
    }

    var isFiniteNumber: Bool {
        if case .number(let value) = self { return value.isFinite }
        return false
    }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByFloatLiteral,
    ExpressibleByIntegerLiteral, ExpressibleByNilLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
    public init(stringLiteral value: String) { self = .string(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(nilLiteral _: ()) { self = .null }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        var object = JSONObject()
        for (key, value) in elements { object[key] = value }
        self = .object(object)
    }
}

extension JSONValue {
    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): true
        case (.bool(let a), .bool(let b)): a == b
        case (.number(let a), .number(let b)): sameNumber(a, b)
        case (.string(let a), .string(let b)): sameText(a, b)
        case (.array(let a), .array(let b)): a == b
        case (.object(let a), .object(let b)): a == b
        default: false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .null: hasher.combine(0 as UInt8)
        case .bool(let value): hasher.combine(value)
        case .number(let value): hasher.combine(value.isNaN ? Double.nan.bitPattern : value.bitPattern)
        case .string(let value): hasher.combine(JSKey(value))
        case .array(let items): hasher.combine(items)
        case .object(let object): hasher.combine(object)
        }
    }
}

func sameNumber(_ lhs: Double, _ rhs: Double) -> Bool {
    lhs.isNaN ? rhs.isNaN : lhs.bitPattern == rhs.bitPattern
}

func strictEquals(_ lhs: JSONValue?, _ rhs: JSONValue?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil): true
    case (.null?, .null?): true
    case (.bool(let a)?, .bool(let b)?): a == b
    case (.number(let a)?, .number(let b)?): a == b
    case (.string(let a)?, .string(let b)?): sameText(a, b)
    default: false
    }
}

func sameValueZero(_ lhs: JSONValue?, _ rhs: JSONValue?) -> Bool {
    strictEquals(lhs, rhs)
}

extension Double {
    var isInteger: Bool { isFinite && rounded(.towardZero) == self }
}

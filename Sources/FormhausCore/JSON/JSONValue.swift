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
    public init(nilLiteral: ()) { self = .null }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        var object = JSONObject()
        for (key, value) in elements { object[key] = value }
        self = .object(object)
    }
}

func strictEquals(_ lhs: JSONValue?, _ rhs: JSONValue?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil): true
    case (.null?, .null?): true
    case (.bool(let a)?, .bool(let b)?): a == b
    case (.number(let a)?, .number(let b)?): a == b
    case (.string(let a)?, .string(let b)?): a.utf16.elementsEqual(b.utf16)
    default: false
    }
}

func sameValueZero(_ lhs: JSONValue?, _ rhs: JSONValue?) -> Bool {
    strictEquals(lhs, rhs)
}

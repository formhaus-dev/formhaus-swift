import Foundation

private struct DynamicKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue _: Int) { nil }
}

extension JSONValue: Codable {
    public init(from decoder: any Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: DynamicKey.self) {
            var object = JSONObject()
            for key in keyed.allKeys { object[key.stringValue] = try keyed.decode(JSONValue.self, forKey: key) }
            self = .object(object)
            return
        }
        if var unkeyed = try? decoder.unkeyedContainer() {
            var items: [JSONValue] = []
            while !unkeyed.isAtEnd { items.append(try unkeyed.decode(JSONValue.self)) }
            self = .array(items)
            return
        }
        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            self = .null
        } else if let flag = try? single.decode(Bool.self) {
            self = .bool(flag)
        } else if let number = try? single.decode(Double.self) {
            self = .number(number)
        } else {
            self = .string(try single.decode(String.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case .bool(let flag):
            var container = encoder.singleValueContainer()
            try container.encode(flag)
        case .number(let number):
            var container = encoder.singleValueContainer()
            try container.encode(number)
        case .string(let text):
            var container = encoder.singleValueContainer()
            try container.encode(text)
        case .array(let items):
            var container = encoder.unkeyedContainer()
            for item in items { try container.encode(item) }
        case .object(let object):
            var container = encoder.container(keyedBy: DynamicKey.self)
            for (key, value) in object { try container.encode(value, forKey: DynamicKey(stringValue: key)) }
        }
    }
}

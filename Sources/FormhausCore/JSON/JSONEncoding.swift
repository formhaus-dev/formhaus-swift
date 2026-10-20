import Foundation

extension JSONValue {
    public func jsonString() -> String {
        jsonStringify(self)
    }

    public func jsonData() -> Data {
        Data(jsonString().utf8)
    }
}

extension StringMap where Value == JSONValue {
    public func jsonString() -> String {
        JSONValue.object(self).jsonString()
    }

    public func jsonData() -> Data {
        JSONValue.object(self).jsonData()
    }
}

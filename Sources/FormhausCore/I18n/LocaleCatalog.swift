import Foundation

public struct PluralForms: Sendable, Hashable {
    public var zero: String?
    public var one: String?
    public var two: String?
    public var few: String?
    public var many: String?
    public var other: String

    public init(zero: String? = nil, one: String? = nil, two: String? = nil, few: String? = nil, many: String? = nil, other: String) {
        self.zero = zero
        self.one = one
        self.two = two
        self.few = few
        self.many = many
        self.other = other
    }

    init?(json: JSONObject) {
        guard let other = json["other"]?.stringValue else { return nil }
        self.init(
            zero: json["zero"]?.stringValue, one: json["one"]?.stringValue, two: json["two"]?.stringValue,
            few: json["few"]?.stringValue, many: json["many"]?.stringValue, other: other)
    }

    subscript(category: String) -> String {
        let forms = ["zero": zero, "one": one, "two": two, "few": few, "many": many]
        return forms[category].flatMap { $0 } ?? other
    }
}

public enum LocaleText: Sendable, Hashable, ExpressibleByStringLiteral {
    case text(String)
    case plural(PluralForms)

    public init(stringLiteral value: String) {
        self = .text(value)
    }

    init?(json: JSONValue) {
        if let text = json.stringValue {
            self = .text(text)
        } else if let forms = json.objectValue.flatMap(PluralForms.init(json:)) {
            self = .plural(forms)
        } else {
            return nil
        }
    }
}

public struct LocaleCatalog: Sendable, Hashable {
    public var locale: String
    public var messages: [MessageKey: LocaleText]
    public var labels: [String: LocaleText]

    public init(locale: String, messages: [MessageKey: LocaleText] = [:], labels: [String: LocaleText] = [:]) {
        self.locale = locale
        self.messages = messages
        self.labels = labels
    }

    public init?(json: JSONValue) {
        guard let locale = json["locale"]?.stringValue else { return nil }
        let texts = { (part: String) in
            (json[part]?.objectValue ?? JSONObject()).reduce(into: [String: LocaleText]()) { result, entry in
                result[entry.0] = LocaleText(json: entry.1)
            }
        }
        let messages = texts("messages").reduce(into: [MessageKey: LocaleText]()) { $0[MessageKey(rawValue: $1.key)] = $1.value }
        self.init(locale: locale, messages: messages, labels: texts("labels"))
    }

    static var bundledFiles: [URL] {
        Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "locales") ?? []
    }

    public static func bundled(_ tag: String) -> LocaleCatalog? {
        guard let file = bundledFiles.first(where: { $0.deletingPathExtension().lastPathComponent == tag }),
            let data = try? Data(contentsOf: file), let json = try? JSONValue(parsing: data)
        else { return nil }
        return LocaleCatalog(json: json)
    }
}

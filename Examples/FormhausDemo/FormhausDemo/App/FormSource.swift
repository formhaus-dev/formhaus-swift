import FormhausCore
import Foundation

struct FormSource {
    let definition: JSONValue
    let overlays: [DemoLanguage: JSONValue]

    init(bundle: Bundle = .main) throws {
        definition = try Self.load("project-inquiry", from: bundle)
        overlays = [.german: try Self.load("project-inquiry.de", from: bundle)]
    }

    func localized(_ language: DemoLanguage) throws -> Localized {
        try localize(definition, overlay: overlays[language] ?? .object(JSONObject()), lang: language.rawValue)
    }

    private static func load(_ name: String, from bundle: Bundle) throws -> JSONValue {
        guard let url = bundle.url(forResource: name, withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
        return try JSONValue(parsing: Data(contentsOf: url))
    }
}

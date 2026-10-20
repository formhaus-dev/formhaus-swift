import Foundation
import Testing

struct ResolvedTokens {
    private let tokens: [String: [String: Any]]

    init(_ context: [String: String] = [:]) throws {
        let directory = try #require(Bundle.module.url(forResource: "tokens", withExtension: nil, subdirectory: "Fixtures"))
        let resolver = try Self.object(directory.appendingPathComponent("formhaus.resolver.json"))
        let sets = try #require(resolver["sets"] as? [String: [String: Any]])
        let modifiers = try #require(resolver["modifiers"] as? [String: [String: Any]])
        var files: [String] = []
        for step in try #require(resolver["resolutionOrder"] as? [[String: String]]) {
            let parts = try #require(step["$ref"]).split(separator: "/").map(String.init)
            if parts[1] == "sets" {
                files += try Self.refs(sets[parts[2]]?["sources"])
            } else {
                let modifier = try #require(modifiers[parts[2]])
                let name = context[parts[2]] ?? modifier["default"] as? String ?? ""
                files += try Self.refs((modifier["contexts"] as? [String: Any])?[name])
            }
        }
        var merged: [String: [String: Any]] = [:]
        for file in files {
            Self.flatten(try Self.object(directory.appendingPathComponent(file)), path: [], type: nil, into: &merged)
        }
        tokens = merged
    }

    func color(_ path: String) throws -> (hex: String, alpha: Double) {
        let value = try #require(try value(path) as? [String: Any])
        return (try #require(value["hex"] as? String).lowercased(), value["alpha"] as? Double ?? 1)
    }

    func dimension(_ path: String) throws -> Double {
        try Self.dimension(try value(path))
    }

    func value(_ path: String) throws -> Any {
        try resolve(try #require(tokens[path]?["$value"], "\(path)"))
    }

    func extensions(_ path: String) throws -> [String: Any] {
        let extensions = try #require(tokens[path]?["$extensions"] as? [String: Any])
        return try #require(extensions["dev.formhaus"] as? [String: Any])
    }

    static func dimension(_ value: Any) throws -> Double {
        let object = try #require(value as? [String: Any])
        #expect(object["unit"] as? String == "px")
        return try #require(object["value"] as? Double)
    }

    private func resolve(_ value: Any) throws -> Any {
        if let text = value as? String, text.hasPrefix("{"), text.hasSuffix("}") {
            return try self.value(String(text.dropFirst().dropLast()))
        }
        if let object = value as? [String: Any], object["colorSpace"] == nil, object["unit"] == nil {
            return try object.mapValues { try resolve($0) }
        }
        return value
    }

    private static func object(_ url: URL) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private static func refs(_ list: Any?) throws -> [String] {
        try #require(list as? [[String: String]]).compactMap { $0["$ref"] }
    }

    private static func flatten(_ node: [String: Any], path: [String], type: String?, into tokens: inout [String: [String: Any]]) {
        let type = node["$type"] as? String ?? type
        if node["$value"] != nil {
            tokens[path.joined(separator: ".")] = node.merging(["$type": type ?? ""]) { current, _ in current }
            return
        }
        for (key, child) in node where !key.hasPrefix("$") {
            if let child = child as? [String: Any] { flatten(child, path: path + [key], type: type, into: &tokens) }
        }
    }
}

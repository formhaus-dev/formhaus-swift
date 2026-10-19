import FormhausCore
import Foundation

struct ScriptError: LocalizedError, CustomStringConvertible {
    let message: String

    var description: String { message }
    var errorDescription: String? { message }
}

@MainActor
final class Script {
    private var deferred: [(name: String, release: () -> Void)] = []

    var pending: [String] { deferred.map(\.name) }

    func reply(_ entry: JSONValue?) async throws -> JSONValue? {
        guard let entry = entry?.objectValue else { return nil }
        guard let name = entry["defer"]?.stringValue else { return try Self.settle(entry) }
        return try await withCheckedThrowingContinuation { continuation in
            let release = { continuation.resume(with: Result { try Self.settle(entry) }) }
            if let index = deferred.firstIndex(where: { sameUnits($0.name, name) }) {
                deferred[index].release = release
            } else {
                deferred.append((name, release))
            }
        }
    }

    private static func settle(_ entry: JSONObject) throws -> JSONValue? {
        if let message = entry["throw"] { throw ScriptError(message: message.stringValue ?? "") }
        return entry["return"]
    }

    func resolve(_ name: String) throws {
        guard let index = deferred.firstIndex(where: { sameUnits($0.name, name) }) else {
            throw ScriptError(message: "No pending deferred reply \"\(name)\"")
        }
        let release = deferred.remove(at: index).release
        release()
    }
}

@MainActor
final class Replies {
    private var entries: [JSONValue]

    init(_ entries: [JSONValue]) {
        self.entries = entries
    }

    func next() -> JSONValue? {
        entries.isEmpty ? nil : entries.removeFirst()
    }
}

@MainActor
final class Flag {
    var isSet = false
}

@MainActor
func drain() async {
    for _ in 0..<16 { await Task.yield() }
}

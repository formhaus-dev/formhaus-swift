import Foundation

public struct MissingKeys: Sendable, Hashable {
    public let messages: [MessageKey]
    public let labels: [String]
}

public func missingKeys(messages: MessageSource? = nil, labels: LabelSource? = nil) -> MissingKeys {
    MissingKeys(
        messages: messages?.catalog.map { catalog in defaultMessageKeys.filter { !hasText(catalog, $0.rawValue) } } ?? [],
        labels: labels?.catalog.map { catalog in defaultLabelKeys.filter { !hasText(catalog, $0) } } ?? [])
}

typealias MissingMessageFn = @Sendable (MessageKey) -> Void

extension MessageSource {
    var catalog: JSONValue? {
        if case .catalog(let catalog) = self { return catalog }
        return nil
    }
}

extension LabelSource {
    var catalog: JSONValue? {
        if case .catalog(let catalog) = self { return catalog }
        return nil
    }
}

private func hasText(_ catalog: JSONValue, _ key: String) -> Bool {
    catalog[key]?.stringValue?.isEmpty == false
}

private final class ReportedTexts: @unchecked Sendable {
    private let lock = NSLock()
    private var keys = Set<String>()

    func first(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return keys.insert(key).inserted
    }
}

private let reportedTexts = ReportedTexts()

@MainActor
private func reportMissing(_ code: IssueCode, _ key: String, _ catalog: String, _ options: FormEngineOptions) {
    guard reportedTexts.first("\(code.rawValue):\(key)") else { return }
    deliver(warning(code, "", "The \(catalog) catalog has no \"\(key)\" text", "Add \"\(key)\" to the \(catalog) catalog"), options)
}

@MainActor
func reportMissingLabel(_ key: String, _ source: LabelSource?, _ options: FormEngineOptions) {
    guard let catalog = source?.catalog, !hasText(catalog, key) else { return }
    reportMissing(.missingLabelKey, key, "labels", options)
}

func missingMessageReporter(_ options: FormEngineOptions) -> MissingMessageFn? {
    #if DEBUG
        guard options.messages?.catalog != nil else { return nil }
        return { key in MainActor.assumeIsolated { reportMissing(.missingMessageKey, key.rawValue, "messages", options) } }
    #else
        return nil
    #endif
}

func watchedResolver(_ source: MessageSource?, _ definition: FormDefinition, _ missing: MissingMessageFn?) -> ResolveMessage {
    let resolve = messageResolver(source, .catalog(definition.messages ?? .null))
    guard let missing, let catalog = source?.catalog else { return resolve }
    return { key, params, field in
        if !hasText(catalog, key.rawValue) { missing(key) }
        return resolve(key, params, field)
    }
}

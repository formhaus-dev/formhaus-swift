import Foundation
import JavaScriptCore

struct JSRegex: @unchecked Sendable {
    private let pattern: JSValue

    init?(_ source: String) {
        guard let pattern = PatternEngine.shared.compile(source) else { return nil }
        self.pattern = pattern
    }

    func test(_ text: String) -> Bool? {
        PatternEngine.shared.test(pattern, text)
    }
}

private final class PatternEngine: @unchecked Sendable {
    static let shared = PatternEngine()
    static let cacheLimit = 256

    private let lock = NSLock()
    private let context: JSContext
    private let constructor: JSValue
    private var cache: [JSKey: JSValue?] = [:]

    private init() {
        context = JSContext(virtualMachine: JSVirtualMachine())
        constructor = context.objectForKeyedSubscript("RegExp")
    }

    func compile(_ source: String) -> JSValue? {
        lock.lock()
        defer { lock.unlock() }
        let key = JSKey(source)
        if let cached = cache[key] { return cached }
        context.exception = nil
        let created = constructor.construct(withArguments: [source])
        let pattern = context.exception == nil && created?.isObject == true ? created : nil
        context.exception = nil
        if cache.count >= Self.cacheLimit { cache.removeAll() }
        cache[key] = .some(pattern)
        return pattern
    }

    func test(_ pattern: JSValue, _ text: String) -> Bool? {
        lock.lock()
        defer { lock.unlock() }
        context.exception = nil
        let result = pattern.invokeMethod("test", withArguments: [text])
        let failed = context.exception != nil
        context.exception = nil
        guard !failed, let result else { return nil }
        return result.toBool()
    }
}

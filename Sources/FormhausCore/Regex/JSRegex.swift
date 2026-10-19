import Foundation
import JavaScriptCore

struct JSRegex: Sendable {
    private let source: String

    init?(_ source: String) {
        guard PatternPool.shared.run({ $0.compile(source) != nil }) else { return nil }
        self.source = source
    }

    init(unchecked source: String) {
        self.source = source
    }

    func test(_ text: String) -> Bool? {
        PatternPool.shared.run { $0.test(source, text) }
    }
}

private final class PatternContext {
    static let cacheLimit = 256

    private let context: JSContext
    private let constructor: JSValue
    private var cache: [JSKey: JSValue?] = [:]

    init() {
        context = JSContext(virtualMachine: JSVirtualMachine())
        constructor = context.objectForKeyedSubscript("RegExp")
    }

    func compile(_ source: String) -> JSValue? {
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

    func test(_ source: String, _ text: String) -> Bool? {
        guard let pattern = compile(source) else { return nil }
        context.exception = nil
        let result = pattern.invokeMethod("test", withArguments: [text])
        let failed = context.exception != nil
        context.exception = nil
        guard !failed, let result, result.isBoolean else { return nil }
        return result.toBool()
    }
}

private final class PatternPool: @unchecked Sendable {
    static let shared = PatternPool(size: 4)

    private let condition = NSCondition()
    private let size: Int
    private var created = 0
    private var idle: [PatternContext] = []

    private init(size: Int) {
        self.size = size
    }

    func run<Result>(_ body: (PatternContext) -> Result) -> Result {
        let context = checkOut()
        defer { checkIn(context) }
        return body(context)
    }

    private func checkOut() -> PatternContext {
        condition.lock()
        defer { condition.unlock() }
        while idle.isEmpty && created >= size { condition.wait() }
        if let context = idle.popLast() { return context }
        created += 1
        return PatternContext()
    }

    private func checkIn(_ context: PatternContext) {
        condition.lock()
        idle.append(context)
        condition.signal()
        condition.unlock()
    }
}

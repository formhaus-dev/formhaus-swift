import os

final class PatternCache: Sendable {
    static let shared = PatternCache()
    static let limit = 256
    static let byteLimit = 16 << 20

    private let state: OSAllocatedUnfairLock<RecentPatterns>

    init(limit: Int = PatternCache.limit, byteLimit: Int = PatternCache.byteLimit) {
        state = OSAllocatedUnfairLock(uncheckedState: RecentPatterns(limit: limit, byteLimit: byteLimit))
    }

    var bytes: Int { state.withLockUnchecked { $0.bytes } }

    func pattern(_ source: String) -> CompiledPattern? {
        if let cached = state.withLockUnchecked({ $0.lookup(source) }) { return cached }
        let compiled = try? CompiledPattern(source)
        let evicted = state.withLockUnchecked { $0.insert(source, compiled) }
        _ = consume evicted
        return compiled
    }
}

private struct RecentPatterns {
    private struct Node {
        var key: String
        var pattern: CompiledPattern?
        var bytes: Int
        var newer = -1
        var older = -1
    }

    let limit: Int
    let byteLimit: Int
    private(set) var bytes = 0
    private var nodes: [Node] = []
    private var free: [Int] = []
    private var positions: [String: Int] = [:]
    private var newest = -1
    private var oldest = -1

    init(limit: Int, byteLimit: Int) {
        self.limit = limit
        self.byteLimit = byteLimit
    }

    mutating func lookup(_ key: String) -> CompiledPattern?? {
        guard let position = positions[key] else { return nil }
        promote(position)
        return .some(nodes[position].pattern)
    }

    mutating func insert(_ key: String, _ pattern: CompiledPattern?) -> [CompiledPattern?] {
        let size = key.utf8.count + (pattern?.bytes ?? 0)
        guard positions[key] == nil, size <= byteLimit else { return [] }
        var evicted: [CompiledPattern?] = []
        while oldest >= 0, positions.count >= limit || bytes + size > byteLimit { evicted.append(evict(oldest)) }
        let node = Node(key: key, pattern: pattern, bytes: size)
        let position: Int
        if let reused = free.popLast() {
            position = reused
            nodes[position] = node
        } else {
            position = nodes.count
            nodes.append(node)
        }
        positions[key] = position
        bytes += size
        link(position)
        return evicted
    }

    private mutating func evict(_ position: Int) -> CompiledPattern? {
        unlink(position)
        let node = nodes[position]
        positions[node.key] = nil
        bytes -= node.bytes
        nodes[position] = Node(key: "", pattern: nil, bytes: 0)
        free.append(position)
        return node.pattern
    }

    private mutating func promote(_ position: Int) {
        guard position != newest else { return }
        unlink(position)
        link(position)
    }

    private mutating func unlink(_ position: Int) {
        let node = nodes[position]
        if node.newer >= 0 { nodes[node.newer].older = node.older } else { newest = node.older }
        if node.older >= 0 { nodes[node.older].newer = node.newer } else { oldest = node.newer }
    }

    private mutating func link(_ position: Int) {
        nodes[position].newer = -1
        nodes[position].older = newest
        if newest >= 0 { nodes[newest].newer = position }
        newest = position
        if oldest < 0 { oldest = position }
    }
}

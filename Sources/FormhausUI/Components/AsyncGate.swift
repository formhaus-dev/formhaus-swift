actor AsyncGate {
    private let width: Int
    private var running = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var next = 0

    init(width: Int) {
        self.width = width
    }

    func run<Value: Sendable>(_ body: @escaping @Sendable () async -> Value) async -> Value {
        if running < width {
            running += 1
        } else {
            await withCheckedContinuation { waiting.append($0) }
        }
        let value = await Task.detached(priority: .userInitiated, operation: body).value
        if next < waiting.count {
            next += 1
            waiting[next - 1].resume()
        } else {
            running -= 1
            waiting.removeAll(keepingCapacity: true)
            next = 0
        }
        return value
    }
}

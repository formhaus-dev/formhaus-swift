import os

final class Deferred<Value: Sendable>: Sendable {
    private let state = OSAllocatedUnfairLock<Value?>(initialState: nil)
    private let make: @Sendable () -> Value

    init(_ make: @escaping @Sendable () -> Value) {
        self.make = make
    }

    var value: Value {
        state.withLock { current in
            if let current { return current }
            let made = make()
            current = made
            return made
        }
    }
}

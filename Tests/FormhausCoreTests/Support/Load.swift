import Foundation
import Testing

enum Load {
    static let heavy = ProcessInfo.processInfo.environment["FORMHAUS_HEAVY_TESTS"] == "1"

    static func sizes<Size>(_ fast: Size, heavy large: Size) -> [Size] {
        heavy ? [fast, large] : [fast]
    }
}

extension Trait where Self == ConditionTrait {
    static var heavy: Self { .enabled(if: Load.heavy, "runs with scripts/heavy-tests.sh") }
}

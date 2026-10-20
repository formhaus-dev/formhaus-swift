import SwiftUI

enum NativeMetrics {
    static let hitTarget: CGFloat = 44
    static let indicator: CGFloat = 18
    static let indicatorRadius: CGFloat = 5
    static let textareaHeight: CGFloat = 112
    static let progressHeight: CGFloat = 4
    static let maxWidth: CGFloat = 640
    static let compactWidth: CGFloat = 480
    static let matrixWidth: CGFloat = 560
}

public struct Motion: Sendable {
    public var quick: Double = 0.14
    public var standard: Double = 0.15
    public var progress: Double = 0.2

    public init() {}
}

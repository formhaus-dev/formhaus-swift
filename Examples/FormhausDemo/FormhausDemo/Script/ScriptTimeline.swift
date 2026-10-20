import CoreGraphics
import Foundation

struct FieldFrame {
    let type: String
    let rect: CGRect
}

@MainActor
final class FieldFrames {
    private(set) var frames: [String: FieldFrame] = [:]

    func update(_ key: String, type: String, rect: CGRect) {
        frames[key] = FieldFrame(type: type, rect: rect)
    }
}

private struct TimelineMark: Encodable {
    let name: String
    let time: Double
}

private struct TimelineTap: Encodable {
    let time: Double
    let kind: String
    let key: String?
    let type: String?
    let frame: [Double]?
    var after: [Double]?
}

private struct TimelineFile: Encodable {
    var marks: [TimelineMark] = []
    var taps: [TimelineTap] = []
}

@MainActor
final class ScriptTimeline {
    private let start = ContinuousClock.now
    private var file = TimelineFile()
    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
        .appendingPathComponent("demo-timeline.json")

    init() {
        save()
    }

    func mark(_ name: String) {
        file.marks.append(TimelineMark(name: name, time: elapsed))
    }

    @discardableResult
    func tap(_ kind: String, key: String? = nil, target: FieldFrame? = nil) -> Int {
        file.taps.append(TimelineTap(time: elapsed, kind: kind, key: key, type: target?.type, frame: Self.values(target)))
        return file.taps.count - 1
    }

    func settle(_ index: Int, target: FieldFrame?) {
        file.taps[index].after = Self.values(target)
    }

    private static func values(_ target: FieldFrame?) -> [Double]? {
        target.map { [$0.rect.minX, $0.rect.minY, $0.rect.width, $0.rect.height].map(Double.init) }
    }

    private var elapsed: Double {
        let duration = ContinuousClock.now - start
        return Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    func save() {
        guard let url, let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

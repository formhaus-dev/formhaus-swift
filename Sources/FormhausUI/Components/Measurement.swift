import SwiftUI

struct MeasuredFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct Measure: ViewModifier {
    @Environment(\.formhausMeasuring) private var measuring
    let name: String

    func body(content: Content) -> some View {
        if measuring {
            content.background(
                GeometryReader { proxy in
                    Color.clear.preference(key: MeasuredFrames.self, value: [name: proxy.frame(in: .named(measureSpace))])
                })
        } else {
            content
        }
    }
}

let measureSpace = "formhaus.measure"

@MainActor
final class RenderLog {
    var bodies: [String: Int] = [:]

    func note(_ name: String) {
        bodies[name, default: 0] += 1
    }
}

extension EnvironmentValues {
    @Entry var formhausMeasuring = false
    @Entry var formhausRenderLog: RenderLog?
}

extension View {
    func measured(_ name: String) -> some View {
        modifier(Measure(name: name))
    }
}

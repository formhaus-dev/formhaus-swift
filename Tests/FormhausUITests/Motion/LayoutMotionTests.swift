import AppKit
import SwiftUI
import Testing

@testable import FormhausUI

@MainActor
@Observable
private final class Shift {
    var moved: Bool

    init(moved: Bool) { self.moved = moved }
}

private struct Probe: View {
    let shift: Shift
    let content: (Bool) -> AnyView

    var body: some View {
        VStack(spacing: 0) {
            if shift.moved { Color.clear.frame(height: 60) }
            content(shift.moved)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(width: 200, height: 200, alignment: .top)
        .background(Color.white)
        .formhausTheme(.pointer)
    }
}

@MainActor
private func topInk(_ host: NSView) -> Int? {
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
    host.cacheDisplay(in: host.bounds, to: rep)
    return (0..<rep.pixelsHigh).first { row in
        guard let color = rep.colorAt(x: rep.pixelsWide / 2, y: row)?.usingColorSpace(.sRGB) else { return false }
        return color.redComponent + color.greenComponent + color.blueComponent < 2.9
    }
}

@MainActor
private func render(moved: Bool, _ content: @escaping (Bool) -> AnyView) -> (Shift, NSHostingView<Probe>) {
    _ = NSApplication.shared
    let shift = Shift(moved: moved)
    let host = NSHostingView(rootView: Probe(shift: shift, content: content))
    host.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
    settle(host)
    return (shift, host)
}

@MainActor
private let cases: [String: (Bool) -> AnyView] = [
    "pending button": { AnyView(Button("Send") {}.buttonStyle(FormButtonStyle(.primary, busy: !$0))) },
    "input focus": { AnyView(Text(verbatim: "Ada").inputChrome(focused: $0, invalid: false, disabled: false)) },
    "option card": { AnyView(Button("Pro") {}.buttonStyle(OptionCardStyle(selected: $0))) },
    "checkbox": { AnyView(ChoiceIndicator(.checkbox, selected: $0)) },
    "radio": { AnyView(ChoiceIndicator(.radio, selected: $0)) },
    "progress": {
        AnyView(
            StepProgressView(
                context: ProgressContext(
                    current: $0 ? 2 : 1, total: 3, counterLabel: "", stepTitle: nil, stepDescription: nil, steps: nil)))
    },
]

@Suite("State motion leaves layout alone", .serialized)
@MainActor
struct LayoutMotionTests {
    @Test(
        "a view whose state changes with the layout lands in its settled place at once",
        arguments: ["checkbox", "input focus", "option card", "pending button", "progress", "radio"])
    func lands(name: String) throws {
        let content = try #require(cases[name])
        let settled = try #require(topInk(render(moved: true, content).1))
        let (shift, host) = render(moved: false, content)
        #expect(try abs(#require(topInk(host)) - settled) > 100)
        shift.moved = true
        host.layoutSubtreeIfNeeded()
        #expect(try abs(#require(topInk(host)) - settled) < 8)
    }
}

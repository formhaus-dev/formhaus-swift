@_spi(Renderer) import FormhausCore
import SwiftUI

struct ScrollTrigger: Equatable {
    let step: Int?
    let focus: FocusRequest?

    @MainActor init(_ model: FormModel) {
        step = model.structure.currentStep?.nodeID
        focus = model.focusRequest
    }
}

enum ScrollTarget: Equatable {
    case field(String)
    case formTop
    case screenTop

    static func resolve(from old: ScrollTrigger, to new: ScrollTrigger, mode: StepScroll) -> ScrollTarget? {
        if new.focus != old.focus, let key = new.focus?.key { return .field(key) }
        guard new.step != old.step else { return nil }
        switch mode {
        case .screenTop: return .screenTop
        case .formTop: return .formTop
        }
    }
}

@MainActor
@Observable
final class TopRequests {
    private(set) var issued = 0

    func request() {
        issued += 1
    }
}

extension EnvironmentValues {
    @Entry var formhausTopRequests: TopRequests?
}

enum ScrollAnchor {
    static let screenReach: CGFloat = 10_000

    @MainActor static func formTop(_ model: FormModel) -> String {
        "formhaus.top.\(ObjectIdentifier(model).hashValue)"
    }

    @MainActor static func screenTop(_ model: FormModel) -> String {
        "formhaus.screen.\(ObjectIdentifier(model).hashValue)"
    }
}

struct StepScroller: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.formhausBehavior) private var behavior
    @Environment(\.formhausTopRequests) private var topRequests
    let model: FormModel
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        content
            .background(alignment: .top) { Color.clear.frame(height: 1).id(ScrollAnchor.formTop(model)).accessibilityHidden(true) }
            .onChange(of: ScrollTrigger(model)) { old, new in
                guard let target = ScrollTarget.resolve(from: old, to: new, mode: behavior.stepScroll) else { return }
                scroll(to: target)
            }
    }

    private func scroll(to target: ScrollTarget) {
        if target == .screenTop, let topRequests {
            topRequests.request()
            return
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            switch target {
            case .field(let key): proxy.scrollTo(key, anchor: .center)
            case .formTop: proxy.scrollTo(ScrollAnchor.formTop(model), anchor: .top)
            case .screenTop: proxy.scrollTo(ScrollAnchor.formTop(model), anchor: UnitPoint(x: 0.5, y: ScrollAnchor.screenReach))
            }
        }
    }
}

struct ScreenTopScroller: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let requests: TopRequests
    let proxy: ScrollViewProxy
    let anchor: String

    func body(content: Content) -> some View {
        let animation: Animation? = reduceMotion ? nil : .easeOut(duration: 0.2)
        if #available(iOS 18, macOS 15, *) {
            content.modifier(EdgeTopPosition(count: requests.issued, animation: animation))
        } else {
            content.onChange(of: requests.issued) {
                withAnimation(animation) { proxy.scrollTo(anchor, anchor: .top) }
            }
        }
    }
}

@available(iOS 18, macOS 15, *)
private struct EdgeTopPosition: ViewModifier {
    @State private var position = ScrollPosition(edge: .top)
    let count: Int
    let animation: Animation?

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onChange(of: count) {
                Task {
                    await Task.yield()
                    withAnimation(animation) { position.scrollTo(edge: .top) }
                }
            }
    }
}

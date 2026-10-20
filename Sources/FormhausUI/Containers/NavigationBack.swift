import SwiftUI

#if os(iOS)
    import UIKit

    private struct NavigationBack: ViewModifier {
        @State private var found: Bool?
        let context: ActionsContext
        let automatic: Bool

        func body(content: Content) -> some View {
            let inBar = automatic && (found ?? context.model.inNavigationBar)
            let shows = inBar && context.state.showBack
            content
                .environment(\.formhausBackInBar, inBar)
                .background {
                    NavigationProbe(found: $found, model: context.model).frame(width: 0, height: 0).accessibilityHidden(true)
                    if shows { Color.clear.navigationBarBackButtonHidden(true) }
                }
                .toolbar {
                    if shows {
                        ToolbarItem(placement: .topBarLeading) { BarBackButton(context: context) }
                    }
                }
        }
    }

    private struct BarBackButton: View {
        let context: ActionsContext

        var body: some View {
            Button(action: context.back) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.backward").fontWeight(.semibold)
                    Text(verbatim: context.state.backLabel)
                }
            }
            .accessibilityLabel(Text(verbatim: context.state.backLabel))
            .disabled(context.busy)
        }
    }

    private struct NavigationProbe: UIViewRepresentable {
        @Binding var found: Bool?
        let model: FormModel

        func makeUIView(context _: Context) -> ProbeView {
            ProbeView()
        }

        func updateUIView(_ view: ProbeView, context _: Context) {
            view.report = { value in
                model.inNavigationBar = value
                if found != value { found = value }
            }
            view.check()
        }
    }

    private final class ProbeView: UIView {
        var report: ((Bool) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            check()
        }

        func check() {
            guard window != nil else { return }
            var responder: UIResponder? = next
            while let current = responder, !(current is UIViewController) { responder = current.next }
            let navigation = (responder as? UIViewController)?.navigationController
            let value = navigation.map { !$0.isNavigationBarHidden } ?? false
            Task { @MainActor [report] in report?(value) }
        }
    }

    extension View {
        func navigationBack(_ context: ActionsContext, automatic: Bool) -> some View {
            modifier(NavigationBack(context: context, automatic: automatic))
        }
    }
#else
    extension View {
        func navigationBack(_: ActionsContext, automatic _: Bool) -> some View {
            self
        }
    }
#endif

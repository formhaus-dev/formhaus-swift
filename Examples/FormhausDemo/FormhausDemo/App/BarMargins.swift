import SwiftUI

#if os(iOS)
    import UIKit

    struct BarReader: UIViewControllerRepresentable {
        let read: @MainActor (UINavigationBar) -> Void

        func makeUIViewController(context _: Context) -> ReaderController {
            ReaderController()
        }

        func updateUIViewController(_ controller: ReaderController, context _: Context) {
            controller.read = read
            controller.apply()
        }

        final class ReaderController: UIViewController {
            var read: @MainActor (UINavigationBar) -> Void = { _ in }

            override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                apply()
            }

            override func viewDidLayoutSubviews() {
                super.viewDidLayoutSubviews()
                apply()
            }

            func apply() {
                guard let bar = navigationController?.navigationBar else { return }
                read(bar)
            }
        }
    }
#endif

extension View {
    func alignsBar(toColumn width: CGFloat, padding: CGFloat) -> some View {
        #if os(iOS)
            background {
                GeometryReader { proxy in
                    let inset = max(padding, (proxy.size.width - width) / 2 + padding)
                    BarReader { bar in
                        let margins = NSDirectionalEdgeInsets(top: 0, leading: inset, bottom: 0, trailing: inset)
                        guard bar.directionalLayoutMargins != margins else { return }
                        bar.preservesSuperviewLayoutMargins = false
                        bar.directionalLayoutMargins = margins
                    }
                }
            }
        #else
            self
        #endif
    }
}

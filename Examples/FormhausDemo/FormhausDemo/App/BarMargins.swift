import SwiftUI

#if os(iOS)
    import UIKit

    struct BarMargins: UIViewControllerRepresentable {
        let inset: CGFloat

        func makeUIViewController(context _: Context) -> MarginController {
            MarginController()
        }

        func updateUIViewController(_ controller: MarginController, context _: Context) {
            controller.inset = inset
            controller.apply()
        }

        final class MarginController: UIViewController {
            var inset: CGFloat = 16

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
                let margins = NSDirectionalEdgeInsets(top: 0, leading: inset, bottom: 0, trailing: inset)
                guard bar.directionalLayoutMargins != margins else { return }
                bar.preservesSuperviewLayoutMargins = false
                bar.directionalLayoutMargins = margins
            }
        }
    }
#endif

extension View {
    func alignsBar(toColumn width: CGFloat, padding: CGFloat) -> some View {
        #if os(iOS)
            background {
                GeometryReader { proxy in
                    BarMargins(inset: max(padding, (proxy.size.width - width) / 2 + padding))
                }
            }
        #else
            self
        #endif
    }
}

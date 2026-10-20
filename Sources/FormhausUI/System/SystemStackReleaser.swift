#if os(iOS)
    import SwiftUI
    import UIKit

    struct StackReleaser: UIViewControllerRepresentable {
        let owner: UUID
        let level: Int

        func makeUIViewController(context _: Context) -> ReleaserController {
            ReleaserController(owner: owner, level: level)
        }

        func updateUIViewController(_: ReleaserController, context _: Context) {}

        final class ReleaserController: UIViewController {
            private let owner: UUID
            private let level: Int
            private var observer: (any NSObjectProtocol)?

            init(owner: UUID, level: Int) {
                self.owner = owner
                self.level = level
                super.init(nibName: nil, bundle: nil)
                let center = NotificationCenter.default
                observer = center.addObserver(forName: .formhausStepsReleased, object: nil, queue: .main) { [weak self] note in
                    let released = note.userInfo?["owner"] as? UUID
                    MainActor.assumeIsolated { if released == self?.owner { self?.release() } }
                }
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                nil
            }

            isolated deinit {
                if let observer { NotificationCenter.default.removeObserver(observer) }
            }

            private func release() {
                let chain = sequence(first: self as UIResponder?) { $0?.next }.lazy.compactMap { $0 as? UIViewController }
                guard let page = chain.first(where: { $0.parent is UINavigationController }),
                    let navigation = page.navigationController, let index = navigation.viewControllers.firstIndex(of: page),
                    index >= level
                else { return }
                let root = navigation.viewControllers[index - level]
                UIView.performWithoutAnimation { navigation.popToViewController(root, animated: false) }
            }
        }
    }
#endif

#if os(iOS)
    import SwiftUI
    import UIKit

    @MainActor
    final class StackClaims {
        static let shared = StackClaims()
        static let changed = Notification.Name("formhaus.stackClaims")
        private var owners: [ObjectIdentifier: ObjectIdentifier] = [:]

        func claim(_ model: ObjectIdentifier, by owner: ObjectIdentifier?) {
            guard owners[model] != owner else { return }
            owners[model] = owner
            NotificationCenter.default.post(name: Self.changed, object: nil)
        }

        func owns(_ model: ObjectIdentifier, _ owner: ObjectIdentifier) -> Bool {
            owners[model] == owner
        }
    }

    struct StackClaim: UIViewControllerRepresentable {
        let model: ObjectIdentifier
        let owner: ObjectIdentifier?

        func makeUIViewController(context _: Context) -> UIViewController {
            UIViewController()
        }

        func updateUIViewController(_: UIViewController, context _: Context) {
            let model = model
            let owner = owner
            Task { @MainActor in StackClaims.shared.claim(model, by: owner) }
        }
    }

    struct StackReleaser: UIViewControllerRepresentable {
        let model: ObjectIdentifier
        let owner: ObjectIdentifier

        func makeUIViewController(context _: Context) -> ReleaserController {
            ReleaserController(model: model, owner: owner)
        }

        func updateUIViewController(_: ReleaserController, context _: Context) {}

        final class ReleaserController: UIViewController {
            private let model: ObjectIdentifier
            private let owner: ObjectIdentifier
            private var observer: (any NSObjectProtocol)?

            init(model: ObjectIdentifier, owner: ObjectIdentifier) {
                self.model = model
                self.owner = owner
                super.init(nibName: nil, bundle: nil)
                let center = NotificationCenter.default
                observer = center.addObserver(forName: StackClaims.changed, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.check() }
                }
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                nil
            }

            isolated deinit {
                if let observer { NotificationCenter.default.removeObserver(observer) }
            }

            private func check() {
                guard !StackClaims.shared.owns(model, owner) else { return }
                let chain = sequence(first: self as UIResponder?) { $0?.next }
                chain.lazy.compactMap { $0 as? UINavigationController }.first?.popToRootViewController(animated: true)
            }
        }
    }
#endif

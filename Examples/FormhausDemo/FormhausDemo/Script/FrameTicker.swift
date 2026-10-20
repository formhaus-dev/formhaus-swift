#if os(iOS)
    import UIKit

    @MainActor
    final class FrameTicker: NSObject {
        static let bits = 6
        static let block: CGFloat = 4
        private static var current: FrameTicker?

        private let cells: [CALayer]
        private var origin: CFTimeInterval?

        private init(window: UIWindow) {
            let host = UIView(frame: CGRect(x: 0, y: 0, width: Self.block * 3, height: Self.block * 3))
            host.isUserInteractionEnabled = false
            host.layer.zPosition = .greatestFiniteMagnitude
            cells = (0..<Self.bits).map { index in
                let layer = CALayer()
                let row = index < 3 ? 0 : (index < 5 ? 1 : 2)
                let column = index < 3 ? index : (index < 5 ? index - 3 : 0)
                layer.frame = CGRect(x: CGFloat(column) * Self.block, y: CGFloat(row) * Self.block, width: Self.block, height: Self.block)
                host.layer.addSublayer(layer)
                return layer
            }
            window.addSubview(host)
            super.init()
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
        }

        static func install() {
            guard current == nil else { return }
            let window = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first
            guard let window else { return }
            current = FrameTicker(window: window)
        }

        @objc private func tick(_ link: CADisplayLink) {
            let start = origin ?? link.targetTimestamp
            origin = start
            let frame = Int(((link.targetTimestamp - start) * 60).rounded())
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for (index, cell) in cells.enumerated() {
                cell.backgroundColor = (frame >> index) & 1 == 1 ? UIColor.black.cgColor : UIColor.white.cgColor
            }
            CATransaction.commit()
        }
    }
#else
    @MainActor
    enum FrameTicker {
        static func install() {}
    }
#endif

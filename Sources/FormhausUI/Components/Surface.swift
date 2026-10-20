import SwiftUI

extension View {
    func surface(
        _ shape: some InsettableShape, fill: Color, border: Color, lineWidth: CGFloat = 1, motion: Animation?
    ) -> some View {
        background { shape.animation(motion) { $0.foregroundStyle(fill) } }
            .overlay { shape.strokeBorder(lineWidth: lineWidth).animation(motion) { $0.foregroundStyle(border) } }
    }
}

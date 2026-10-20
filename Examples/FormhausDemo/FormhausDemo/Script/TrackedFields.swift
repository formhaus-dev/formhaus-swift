import FormhausUI
import SwiftUI

extension FormComponents {
    func tracking(_ frames: FieldFrames) -> FormComponents {
        ["text", "email", "radio", "multiselect", "scale", "rating"].reduce(self) { components, type in
            components.field(type) { context in
                TrackedField(context: context)
                    .onGeometryChange(for: CGRect.self) {
                        $0.frame(in: .global)
                    } action: { rect in
                        frames.update(context.key, type: context.field.type, rect: rect)
                    }
            }
        }
    }
}

private struct TrackedField: View {
    let context: FieldContext

    var body: some View {
        switch context.field.type {
        case "radio": RadioField(context)
        case "multiselect": MultiselectField(context)
        case "scale": ScaleField(context)
        case "rating": RatingField(context)
        default: TextInputField(context)
        }
    }
}

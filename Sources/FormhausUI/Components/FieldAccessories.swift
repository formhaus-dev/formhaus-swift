import SwiftUI

struct FieldAccessories: View {
    let context: FieldContext
    let clearable: Bool
    let clear: () -> Void

    var body: some View {
        LoadingIndicator(visible: context.loading)
        if clearable, !context.isRequired, !context.isLocked {
            IconButton(systemName: "xmark.circle.fill", label: "\(context.label("clear")), \(context.label)", embedded: true, action: clear)
        }
    }
}

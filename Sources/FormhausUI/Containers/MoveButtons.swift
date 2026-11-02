import SwiftUI

struct MoveButtons: View {
    let item: GroupItemContext
    var system = false

    var body: some View {
        HStack(spacing: 0) {
            MoveButton(item: item, up: true, system: system)
            MoveButton(item: item, up: false, system: system)
        }
    }
}

private struct MoveButton: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let item: GroupItemContext
    let up: Bool
    let system: Bool

    var body: some View {
        let target = item.index + (up ? -1 : 1)
        let locked = item.disabled || !(0..<item.count).contains(target)
        let label = up ? item.moveUpLabel : item.moveDownLabel
        Button {
            item.move(target)
        } label: {
            Image(systemName: up ? "arrow.up" : "arrow.down")
                .fontWeight(.semibold)
                .frame(minWidth: tokens.controls.hitTarget, minHeight: tokens.controls.hitTarget)
                .contentShape(Rectangle())
        }
        .modifier(MoveButtonStyle(system: system))
        .disabled(locked)
        .help(label)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityHint(Text(verbatim: item.title))
        .spokenFocus(up ? item.moveUpFocus : item.moveDownFocus, model: item.model, disabled: locked, $focused)
    }
}

private struct MoveButtonStyle: ViewModifier {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.isEnabled) private var enabled
    let system: Bool

    func body(content: Content) -> some View {
        if system {
            content.buttonStyle(.borderless)
        } else {
            content.buttonStyle(.plain).foregroundStyle(enabled ? tokens.colors.text : tokens.colors.textMuted.opacity(0.5))
        }
    }
}

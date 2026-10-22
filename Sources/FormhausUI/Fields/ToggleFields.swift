import SwiftUI

public struct CheckboxField: View {
    @FocusState private var focused: Bool
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        FieldShell(context, variant: .inline) {
            Toggle(isOn: context.boolBinding) {
                Text(verbatim: context.label).formhausText(.option).fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(CheckboxStyle(invalid: context.isInvalid))
            .accessibilityLabel(Text(verbatim: context.accessibilityName))
            .accessibilityHint(Text(verbatim: context.helperText ?? ""))
            .disabled(context.isLocked)
            .formhausFocus(context, $focused)
        }
    }
}

public struct CheckboxStyle: ToggleStyle {
    let invalid: Bool

    public init(invalid: Bool = false) {
        self.invalid = invalid
    }

    public func makeBody(configuration: Configuration) -> some View {
        CheckboxBody(configuration: configuration, invalid: invalid)
    }
}

private struct CheckboxBody: View {
    @Environment(\.formhausTokens) private var tokens
    let configuration: ToggleStyleConfiguration
    let invalid: Bool

    var body: some View {
        let offset = tokens.typography.body * 0.36
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: tokens.spacing.s5) {
                FocusedIndicator(selected: configuration.isOn, invalid: invalid)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + offset }
                configuration.label.frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: tokens.controls.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

private struct FocusedIndicator: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.isFocused) private var focused
    let selected: Bool
    let invalid: Bool

    var body: some View {
        ChoiceIndicator(.checkbox, selected: selected, invalid: invalid)
            .overlay(FocusRing(visible: focused, radius: tokens.radii.indicator, offset: 2))
    }
}

public struct SwitchField: View {
    @FocusState private var focused: Bool
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        FieldShell(context, variant: .row) {
            Toggle(isOn: context.boolBinding) {
                Text(verbatim: context.label).formhausText(.option).fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(SwitchRowStyle(loading: context.loading, invalid: context.isInvalid))
            .accessibilityLabel(Text(verbatim: context.accessibilityName))
            .accessibilityHint(Text(verbatim: context.helperText ?? ""))
            .disabled(context.isLocked)
            .formhausFocus(context, $focused)
        }
    }
}

private struct SwitchRowStyle: ToggleStyle {
    let loading: Bool
    let invalid: Bool

    func makeBody(configuration: Configuration) -> some View {
        SwitchRow(configuration: configuration, loading: loading, invalid: invalid)
    }
}

private struct SwitchRow: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let configuration: ToggleStyleConfiguration
    let loading: Bool
    let invalid: Bool

    var body: some View {
        let offset = tokens.typography.body * 0.36
        HStack(alignment: .firstTextBaseline, spacing: tokens.spacing.s5) {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { configuration.isOn.toggle() }
                .accessibilityHidden(true)
            LoadingIndicator(visible: loading)
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(tokens.colors.primary)
                .focusEffectDisabled()
                .focused($focused)
                .overlay {
                    Capsule().strokeBorder(tokens.colors.error, lineWidth: 1.5)
                        .opacity(invalid && !configuration.isOn ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .overlay { FocusRing(visible: focused, radius: tokens.controls.hitTarget, offset: 2) }
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + offset }
        }
        .frame(minHeight: tokens.controls.hitTarget)
        .contentShape(Rectangle())
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

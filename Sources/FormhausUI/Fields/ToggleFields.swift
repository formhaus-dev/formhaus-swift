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
                Text(context.label).formhausText(.option).fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(CheckboxStyle(invalid: context.isInvalid))
            .accessibilityLabel(context.accessibilityName)
            .accessibilityHint(context.helperText ?? "")
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
                ChoiceIndicator(.checkbox, selected: configuration.isOn, invalid: invalid)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + offset }
                configuration.label.frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: tokens.controls.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
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
                Text(context.label).formhausText(.option).fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(SwitchRowStyle())
            .accessibilityLabel(context.accessibilityName)
            .accessibilityHint(context.helperText ?? "")
            .disabled(context.isLocked)
            .formhausFocus(context, $focused)
        }
    }
}

private struct SwitchRowStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        SwitchRow(configuration: configuration)
    }
}

private struct SwitchRow: View {
    @Environment(\.formhausTokens) private var tokens
    let configuration: ToggleStyleConfiguration

    var body: some View {
        HStack(alignment: .center, spacing: tokens.spacing.s5) {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { configuration.isOn.toggle() }
                .accessibilityHidden(true)
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(tokens.colors.primary)
        }
        .frame(minHeight: tokens.controls.hitTarget)
    }
}

@_spi(Renderer) import FormhausCore
import SwiftUI

struct SystemField: View {
    let context: FieldContext

    var body: some View {
        switch context.field.type {
        case "text", "email", "phone", "number", "password": SystemTextRow(context: context)
        case "autocomplete": SystemTextRow(context: context, suggests: true)
        case "textarea": SystemTextArea(context: context)
        case _ where context.field.hasPictureOptions: SystemPictures(context: context)
        case "select", "radio", "multiselect": SystemPickerRow(context: context)
        case "checkbox", "switch": SystemToggleRow(context: context)
        case "date", "time", "datetime": SystemDateRow(context: context)
        case "file": SystemFileRow(context: context)
        case "scale": SystemScale(context: context)
        case "rating": SystemRating(context: context)
        case "hidden": EmptyView()
        default: SystemRow(context: context) { LabeledContent(context.label) { Text(verbatim: context.field.type) } }
        }
    }
}

func isSystemBlock(_ field: FormField, _ components: FormComponents) -> Bool {
    guard components.fields[field.type] == nil else { return false }
    return ["textarea", "scale", "rating"].contains(field.type) || field.hasPictureOptions
}

extension EnvironmentValues {
    @Entry var formhausNested = false
}

struct SystemRow<Content: View>: View {
    let context: FieldContext
    let content: Content

    init(context: FieldContext, @ViewBuilder content: () -> Content) {
        self.context = context
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
            SystemNotes(context: context)
        }
        .disabled(context.isLocked)
        .formhausScrollAnchor(context)
    }
}

struct SystemNotes: View {
    @Environment(\.formhausFooterErrors) private var footerErrors
    let context: FieldContext

    var body: some View {
        if let helper = context.helperText {
            Text(helper).font(.footnote).systemSecondaryText().fixedSize(horizontal: false, vertical: true)
        }
        if !footerErrors, let error = context.error, !error.isEmpty { SystemErrorText(text: error) }
    }
}

struct SystemErrorText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear { announce(text) }
            .onChange(of: text) { _, message in announce(message) }
    }
}

struct SystemBlock<Content: View>: View {
    @Environment(\.formhausNested) private var nested
    let context: FieldContext
    let content: Content

    init(context: FieldContext, @ViewBuilder content: () -> Content) {
        self.context = context
        self.content = content()
    }

    var body: some View {
        if nested {
            VStack(alignment: .leading, spacing: 8) {
                Text(context.label).accessibilityLabel(context.accessibilityName).accessibilityAddTraits(.isHeader)
                content
                SystemNotes(context: context)
            }
            .disabled(context.isLocked)
            .formhausScrollAnchor(context)
        } else {
            Section {
                content.disabled(context.isLocked).formhausScrollAnchor(context)
            } header: {
                HStack(alignment: .firstTextBaseline) {
                    Text(context.label)
                    Spacer(minLength: 8)
                    if context.isRequired { Text(context.requiredPrompt) }
                }
                .textCase(nil)
                .systemSecondaryText()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(context.accessibilityName)
                .accessibilityAddTraits(.isHeader)
            } footer: {
                VStack(alignment: .leading, spacing: 4) { SystemNotes(context: context) }
            }
        }
    }
}

extension FieldContext {
    var requiredPrompt: String {
        let text = text(forLabel: "required")
        return text.prefix(1).localizedUppercase + text.dropFirst()
    }

    var prompt: String {
        field.placeholder ?? field.mask?.stringValue ?? (isRequired ? requiredPrompt : optionalPrompt)
    }

    var optionalPrompt: String {
        let text = text(forLabel: "optional")
        return text.prefix(1).localizedUppercase + text.dropFirst()
    }
}

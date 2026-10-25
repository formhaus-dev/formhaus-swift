@_spi(Renderer) import FormhausCore
import SwiftUI

struct SystemField: View {
    @Environment(\.formhausBehavior) private var behavior
    let context: FieldContext

    var body: some View {
        switch context.field.type {
        case "text", "email", "phone", "number", "password": SystemTextRow(context: context)
        case "autocomplete": SystemTextRow(context: context, suggests: true)
        case "textarea": SystemTextArea(context: context)
        case _ where context.field.hasPictureOptions: SystemPictures(context: context)
        case _ where isInlineChoice(context.field, limit: behavior.inlineChoiceLimit): SystemChoiceList(context: context)
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

func isSystemBlock(_ field: FormField, _ components: FormComponents, limit: Int) -> Bool {
    guard components.fields[field.type] == nil else { return false }
    return ["textarea", "scale", "rating"].contains(field.type) || field.hasPictureOptions || isInlineChoice(field, limit: limit)
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
        .formhausTestContainer(context.testId)
        .disabled(context.isLocked)
        .scrollVisibility(context.key)
        .formhausScrollAnchor(context)
    }
}

struct SystemRowLabel: View {
    @Environment(\.formhausTokens) private var tokens
    let context: FieldContext

    var body: some View {
        tokens.marked(context.label, required: context.isRequired).foregroundStyle(Color.primary)
            .accessibilityLabel(Text(verbatim: context.accessibilityName))
    }
}

struct SystemNotes: View {
    let context: FieldContext
    var showsError = true

    var body: some View {
        if let helper = context.helperText {
            Text(verbatim: helper).font(.footnote).systemSecondaryText().fixedSize(horizontal: false, vertical: true)
        }
        if showsError { SystemFieldError(context: context) }
    }
}

struct SystemFieldError: View {
    let context: FieldContext

    var body: some View {
        if let error = context.error, !error.isEmpty { SystemErrorText(text: error) }
    }
}

struct SystemErrorText: View {
    @Environment(\.formhausTokens) private var tokens
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.footnote)
            .foregroundStyle(tokens.colors.error)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear { announce(text) }
            .onChange(of: text) { _, message in announce(message) }
    }
}

struct SystemBlock<Content: View>: View {
    @Environment(\.formhausNested) private var nested
    @Environment(\.formhausTokens) private var tokens
    let context: FieldContext
    let anchored: Bool
    let rows: Bool
    let content: Content

    init(context: FieldContext, anchored: Bool = true, rows: Bool = false, @ViewBuilder content: () -> Content) {
        self.context = context
        self.anchored = anchored
        self.rows = rows
        self.content = content()
    }

    var body: some View {
        if nested {
            VStack(alignment: .leading, spacing: 8) {
                SystemRowLabel(context: context).accessibilityAddTraits(.isHeader)
                if errorFirst { SystemFieldError(context: context) }
                content
                SystemNotes(context: context, showsError: !errorFirst)
            }
            .formhausTestContainer(context.testId)
            .disabled(context.isLocked && !rows)
            .scrollVisibility(context.key)
            .formhausScrollAnchor(context)
        } else {
            Section {
                content.formhausTestContainer(rows ? nil : context.testId).disabled(context.isLocked && !rows).scrollAnchor(
                    anchored, context)
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    tokens.marked(context.label, required: context.isRequired)
                        .systemSecondaryText()
                        .accessibilityLabel(Text(verbatim: context.accessibilityName))
                        .accessibilityAddTraits(.isHeader)
                        .formhausTestId(rows ? context.testId : nil)
                    if errorFirst { SystemFieldError(context: context) }
                }
                .textCase(nil)
                .questionVisibility(context.key)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    SystemNotes(context: context, showsError: !errorFirst)
                    if context.isRequired, errorFirst || (context.error ?? "").isEmpty {
                        Text(verbatim: " ").font(.footnote).accessibilityHidden(true)
                    }
                }
            }
        }
    }
}

extension SystemBlock {
    fileprivate var errorFirst: Bool { !context.reveals.isEmpty }
}

extension View {
    @ViewBuilder
    fileprivate func scrollAnchor(_ anchored: Bool, _ context: FieldContext) -> some View {
        if anchored { scrollVisibility(context.key).formhausScrollAnchor(context) } else { self }
    }
}

extension FieldContext {
    var prompt: String {
        placeholder ?? field.mask?.stringValue ?? ""
    }

    var choicePrompt: String {
        placeholder ?? text(forLabel: "select")
    }
}

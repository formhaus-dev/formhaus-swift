@_spi(Renderer) import FormhausCore
import SwiftUI

public struct FormhausField: View {
    @Environment(\.formhausComponents) private var components
    let field: FormField
    let key: String
    let model: FormModel

    public init(_ field: FormField, key: String? = nil, model: FormModel) {
        self.field = field
        self.key = key ?? field.key
        self.model = model
    }

    public var body: some View {
        let context = FieldContext(field: field, key: key, state: model.field(key), model: model)
        if let custom = components.fields[field.type] {
            custom(context)
        } else if components.builtIns {
            BuiltInField(context: context)
        } else {
            UnsupportedField(type: field.type)
        }
    }
}

struct BuiltInField: View {
    let context: FieldContext

    var body: some View {
        switch context.field.type {
        case "text", "email", "phone", "number", "password": TextInputField(context)
        case "textarea": TextAreaField(context)
        case "autocomplete": AutocompleteField(context)
        case "select": SelectField(context)
        case "radio": RadioField(context)
        case "multiselect": MultiselectField(context)
        case "checkbox": CheckboxField(context)
        case "switch": SwitchField(context)
        case "date", "time", "datetime": DateField(context)
        case "file": FileField(context)
        case "hidden": EmptyView()
        default: UnsupportedField(type: context.field.type)
        }
    }
}

struct UnsupportedField: View {
    @Environment(\.formhausTokens) private var tokens
    let type: String

    var body: some View {
        Text(verbatim: "Unsupported field type: \(type)")
            .formhausText(.helper)
            .padding(tokens.spacing.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: tokens.radii.control, style: .continuous)
                    .strokeBorder(tokens.colors.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
    }
}

@_spi(Renderer) import FormhausCore
import SwiftUI

public struct RadioField: View {
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        ChoiceList(
            context: context, shape: .radio, isSelected: { $0 == context.text && context.value != nil },
            choose: { context.commit(.string($0)) })
    }
}

public struct MultiselectField: View {
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        ChoiceList(context: context, shape: .checkbox, isSelected: selected.contains) { value in
            let current = selected
            let next = current.contains(value) ? current.filter { $0 != value } : current + [value]
            context.setValue(.array(next.map(JSONValue.string)))
        }
    }

    private var selected: [String] {
        context.value?.arrayValue?.compactMap(\.stringValue) ?? []
    }
}

struct ChoiceList: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    @State private var zoomed: Zoomed?
    let context: FieldContext
    let shape: IndicatorShape
    let isSelected: (String) -> Bool
    let choose: (String) -> Void

    var body: some View {
        FieldShell(context, variant: .group) {
            options
                .disabled(context.isLocked)
                .formhausFocus(context, $focused)
        }
        .sheet(item: $zoomed) { zoomed in
            ImageViewer(title: zoomed.label, source: zoomed.image, closeLabel: context.label("close"))
        }
    }

    @ViewBuilder private var options: some View {
        let options = context.options
        if options.contains(where: { $0.image?.isEmpty == false }) {
            ColumnGrid(
                columns: clampedInt(context.field.columns.map(Double.init), 1...4), minimumWidth: tokens.controls.optionImageWidth,
                compactWidth: tokens.controls.compactWidth, spacing: tokens.spacing.s5
            ) {
                ForEach(options, id: \.self) { option in picture(option) }
            }
        } else if context.field.layout?.stringValue == "inline" {
            FlowLayout(spacing: tokens.spacing.s3) {
                ForEach(options, id: \.self) { option in card(option).fixedSize() }
            }
        } else {
            VStack(alignment: .leading, spacing: tokens.spacing.s3) {
                ForEach(options, id: \.self) { option in card(option) }
            }
        }
    }

    private func card(_ option: FieldOption) -> some View {
        let value = option.value ?? ""
        let selected = isSelected(value)
        return Button {
            choose(value)
        } label: {
            OptionRow(shape, label: option.label ?? value, selected: selected, invalid: context.isInvalid)
        }
        .buttonStyle(OptionCardStyle(selected: selected, invalid: context.isInvalid))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(context.helperText ?? "")
    }

    private func picture(_ option: FieldOption) -> some View {
        let value = option.value ?? ""
        let selected = isSelected(value)
        return Button {
            choose(value)
        } label: {
            VStack(alignment: .leading, spacing: tokens.spacing.s3) {
                OptionImage(source: option.image ?? "")
                OptionRow(shape, label: option.label ?? value, selected: selected, invalid: context.isInvalid)
            }
            .padding(.top, tokens.spacing.s3 - tokens.spacing.s5)
        }
        .buttonStyle(OptionCardStyle(selected: selected, invalid: context.isInvalid))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .overlay(alignment: .topTrailing) {
            if option.image?.isEmpty == false {
                let inset = (tokens.controls.hitTarget - tokens.controls.iconButton) / 2
                ZoomButton(label: context.label("enlargeImage", ["label": .string(option.label ?? "")])) {
                    zoomed = Zoomed(id: value, label: option.label ?? value, image: option.image ?? "")
                }
                .padding(.top, 2 * tokens.spacing.s3 - inset)
                .padding(.trailing, tokens.spacing.s6 + tokens.spacing.s3 - inset)
            }
        }
    }
}

private struct Zoomed: Identifiable {
    let id: String
    let label: String
    let image: String
}

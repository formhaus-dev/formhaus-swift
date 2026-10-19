@_spi(Renderer) import FormhausCore
import SwiftUI

public struct RadioField: View {
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        ChoiceList(context: context, shape: .radio)
    }
}

public struct MultiselectField: View {
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        ChoiceList(context: context, shape: .checkbox)
    }
}

@MainActor
struct ChoiceSelection {
    let context: FieldContext

    var multiple: Bool { context.field.type == "multiselect" }

    var values: [String] { Self.values(context.state.value, multiple: multiple) }

    static func values(_ value: JSONValue?, multiple: Bool) -> [String] {
        if multiple { return value?.arrayValue?.compactMap(\.stringValue) ?? [] }
        guard let value, !value.isNull else { return [] }
        return [value.stringValue ?? value.numberValue.map(numberText) ?? ""]
    }

    func choose(_ value: String) {
        guard multiple else {
            context.commit(.string(value))
            return
        }
        let current = values
        let next = current.contains(value) ? current.filter { $0 != value } : current + [value]
        context.setValue(.array(next.map(JSONValue.string)))
    }
}

struct ChoiceList: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    @State private var zoomed: Zoomed?
    let context: FieldContext
    let shape: IndicatorShape

    var body: some View {
        FieldShell(context, variant: .group) {
            options
                .disabled(context.isLocked)
                .formhausFocus(context, $focused)
        }
        .sheet(item: $zoomed) { zoomed in
            ImageViewer(title: zoomed.label, source: zoomed.image, closeLabel: context.text(forLabel: "close"))
        }
    }

    @ViewBuilder private var options: some View {
        let options = context.options
        let selected = Set(ChoiceSelection.values(context.value, multiple: shape == .checkbox))
        if options.contains(where: { $0.image?.isEmpty == false }) {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: tokens.spacing.s5) {
                ForEach(options, id: \.self) { option in card(option, selected: selected, picture: true) }
            }
        } else if context.field.layout?.stringValue == "inline" {
            FlowLayout(spacing: tokens.spacing.s3) {
                ForEach(options, id: \.self) { option in card(option, selected: selected, picture: false) }
            }
        } else {
            LazyVStack(alignment: .leading, spacing: tokens.spacing.s3) {
                ForEach(options, id: \.self) { option in card(option, selected: selected, picture: false) }
            }
        }
    }

    private var gridColumns: [GridItem] {
        let spacing = tokens.spacing.s5
        if let columns = context.field.columns, (1...4).contains(columns) {
            return Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: columns)
        }
        return [
            GridItem(
                .adaptive(minimum: min(tokens.controls.optionImageWidth, 160 * max(1, tokens.scale))), spacing: spacing, alignment: .top)
        ]
    }

    private func card(_ option: FieldOption, selected: Set<String>, picture: Bool) -> some View {
        let value = option.value ?? ""
        let selection = ChoiceSelection(context: context)
        return ChoiceCard(
            option: option, shape: shape, selected: selected.contains(value), invalid: context.isInvalid, picture: picture,
            hint: context.helperText ?? "",
            zoomLabel: context.text(forLabel: "enlargeImage", ["label": .string(option.label ?? "")]),
            choose: { selection.choose(value) },
            zoom: { zoomed = Zoomed(id: value, label: option.label ?? value, image: option.image ?? "") }
        )
        .equatable()
    }
}

private struct Zoomed: Identifiable {
    let id: String
    let label: String
    let image: String
}

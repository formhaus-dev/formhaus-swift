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
public struct ChoiceSelection {
    let context: FieldContext

    public init(context: FieldContext) {
        self.context = context
    }

    public var multiple: Bool { context.field.type == "multiselect" }

    public var values: [String] { Self.values(context.state.value, multiple: multiple) }

    public func isSelected(_ value: String) -> Bool {
        values.contains(value)
    }

    static func values(_ value: JSONValue?, multiple: Bool) -> [String] {
        if multiple { return value?.arrayValue?.compactMap(\.stringValue) ?? [] }
        guard let value, !value.isNull else { return [] }
        return [value.stringValue ?? value.numberValue.map(numberText) ?? ""]
    }

    public func choose(_ value: String) {
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
        .onAppear {
            InlineImages.shared.prefetch(
                context.options.prefix(64).compactMap { option in option.safeImage.map { ImageKey($0, digest: option.imageKey) } })
        }
        .sheet(item: $zoomed) { zoomed in
            ImageViewer(title: zoomed.label, key: zoomed.image, closeLabel: context.text(forLabel: "close"))
        }
    }

    @ViewBuilder private var options: some View {
        let options = context.options
        let selected = Set(ChoiceSelection.values(context.value, multiple: shape == .checkbox))
        if options.contains(where: { $0.image?.isEmpty == false }) {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: tokens.spacing.s5) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in card(option, selected: selected, picture: true) }
            }
        } else if context.field.layout?.stringValue == "inline" {
            FlowLayout(spacing: tokens.spacing.s3) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in card(option, selected: selected, picture: false) }
            }
        } else {
            LazyVStack(alignment: .leading, spacing: tokens.spacing.s3) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in card(option, selected: selected, picture: false) }
            }
        }
    }

    private var gridColumns: [GridItem] {
        let spacing = tokens.spacing.s5
        if tokens.scale >= 1.6 { return [GridItem(.flexible(), spacing: spacing, alignment: .top)] }
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
        let image = ImageKey(option.safeImage ?? "", digest: option.imageKey)
        return ChoiceCard(
            option: option, shape: shape, selected: selected.contains(value), picture: picture,
            hint: context.helperText ?? "",
            zoomLabel: context.text(forLabel: "enlargeImage", ["label": .string(option.label ?? "")]),
            choose: { selection.choose(value) },
            zoom: { zoomed = Zoomed(id: value, label: option.label ?? value, image: image) }
        )
        .equatable()
    }
}

private struct Zoomed: Identifiable {
    let id: String
    let label: String
    let image: ImageKey
}

@_spi(Renderer) import FormhausCore
import SwiftUI

struct SystemPictures: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        let selection = ChoiceSelection(context: context)
        let selected = Set(selection.values)
        SystemBlock(context: context) {
            LazyVGrid(columns: columns, alignment: .center, spacing: 16) {
                ForEach(Array(context.options.enumerated()), id: \.offset) { _, option in
                    let value = option.value ?? ""
                    SystemPictureTile(option: option, selected: selected.contains(value)) {
                        selection.choose(value)
                    }
                }
            }
            .padding(.vertical, 8)
            .formhausFocus(context, $focused)
            .sensoryFeedback(.selection, trigger: selected)
        }
        .onAppear {
            let keys = context.options.prefix(64).compactMap { option in option.safeImage.map { ImageKey($0, digest: option.imageKey) } }
            OptionImages.shared.prefetch(keys)
        }
    }

    private var columns: [GridItem] {
        let count = typeSize.isAccessibilitySize ? 1 : min(4, max(1, context.field.columns ?? 2))
        return Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: count)
    }
}

private struct SystemPictureTile: View {
    let option: FieldOption
    let selected: Bool
    let choose: () -> Void

    var body: some View {
        let label = option.label ?? option.value ?? ""
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Button(action: choose) {
            VStack(spacing: 8) {
                SystemOptionImage(option: option)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator), lineWidth: selected ? 3 : 1))
                Text(verbatim: label).font(.subheadline).foregroundStyle(Color.primary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: indicator)
                    .font(.title3)
                    .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(systemSecondary))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var indicator: String {
        selected ? "checkmark.circle.fill" : "circle"
    }
}

private struct SystemOptionImage: View {
    let option: FieldOption

    var body: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay { FormhausOptionImage(option: option) }
            .background(.quaternary)
    }
}

@_spi(Renderer) import FormhausCore
import SwiftUI

struct ChoiceCard: View, Equatable {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.formhausRenderLog) private var renderLog
    let option: FieldOption
    let shape: IndicatorShape
    let selected: Bool
    let picture: Bool
    let hint: String
    let zoomLabel: String
    let choose: @MainActor () -> Void
    let zoom: @MainActor () -> Void

    nonisolated static func == (lhs: ChoiceCard, rhs: ChoiceCard) -> Bool {
        lhs.option == rhs.option && lhs.shape == rhs.shape && lhs.selected == rhs.selected
            && lhs.picture == rhs.picture && lhs.hint == rhs.hint && lhs.zoomLabel == rhs.zoomLabel
    }

    var body: some View {
        renderLog?.note(option.value ?? "")
        return card
    }

    private var card: some View {
        let label = option.label ?? option.value ?? ""
        return Button(action: choose) {
            VStack(alignment: .leading, spacing: tokens.spacing.s3) {
                if picture, let image = option.safeImage { OptionImage(key: ImageKey(image, digest: option.imageKey)) }
                OptionRow(shape, label: label, selected: selected)
            }
            .padding(.top, picture ? tokens.spacing.s3 - tokens.spacing.s5 : 0)
            .frame(maxHeight: picture ? .infinity : nil, alignment: .topLeading)
        }
        .buttonStyle(OptionCardStyle(selected: selected))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(Text(verbatim: hint))
        .overlay(alignment: .topTrailing) {
            if picture, option.safeImage != nil {
                let inset = (tokens.controls.hitTarget - tokens.controls.iconButton) / 2
                ZoomButton(label: zoomLabel, action: zoom)
                    .padding(.top, 2 * tokens.spacing.s3 - inset)
                    .padding(.trailing, tokens.spacing.s6 + tokens.spacing.s3 - inset)
            }
        }
    }
}

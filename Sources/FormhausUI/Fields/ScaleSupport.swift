@_spi(Renderer) import FormhausCore
import SwiftUI

struct ScalePoints {
    let points: [Int]
    let anchors: [String?]

    init(_ context: FieldContext) {
        let range = context.field.scaleRange ?? (1, 5)
        let low = clampedInt(range.min, -1_000_000...1_000_000) ?? 1
        let high = clampedInt(range.max, -1_000_000...1_000_000) ?? 5
        let count = min(11, max(0, high - low + 1))
        points = Array(low..<(low + count))
        let middle = Int((Double(low + high) / 2).rounded(.down))
        let roles = [low, middle, high]
        anchors = roles.enumerated().map { index, point in
            if index == 1, point == low || point == high { return nil }
            return context.options.first { $0.value == String(point) }?.label
        }
    }

    var low: Int { points.first ?? 1 }
    var high: Int { points.last ?? 1 }

    func anchor(for point: Int) -> String? {
        if point == low { return anchors[0] }
        if point == high { return anchors[2] }
        let middle = Int((Double(low + high) / 2).rounded(.down))
        return point == middle ? anchors[1] : nil
    }

    func point(forDigit key: Character) -> Int? {
        guard let digit = key.wholeNumberValue else { return nil }
        let point = digit == 0 && low > 0 ? 10 : digit
        return points.contains(point) ? point : nil
    }

    func selected(_ value: JSONValue?) -> Int? {
        guard let number = value?.numberValue, let point = Int(exactly: number) else { return nil }
        return points.contains(point) ? point : nil
    }
}

struct ScaleGrid: Layout {
    let spacing: CGFloat

    private func grid(_ width: CGFloat, _ count: Int) -> ColumnGrid {
        var columns = count
        if count >= 8, width < 444 { columns = count == 8 ? 4 : 5 }
        if count >= 10, width < 544 { columns = count == 10 ? 5 : 6 }
        return ColumnGrid(columns: max(1, columns), minimumWidth: 0, compactWidth: 0, spacing: spacing)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 440
        return grid(width, subviews.count).sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        grid(bounds.width, subviews.count).placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
    }
}

struct ScaleAnchors: View {
    @Environment(\.formhausTokens) private var tokens
    let anchors: [String?]

    var body: some View {
        if anchors.contains(where: { $0 != nil }) {
            HStack(alignment: .top, spacing: tokens.spacing.s5) {
                Text(anchors[0] ?? "").frame(maxWidth: .infinity, alignment: .leading)
                if let middle = anchors[1] { Text(middle).multilineTextAlignment(.center) }
                Text(anchors[2] ?? "").multilineTextAlignment(.trailing).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .formhausText(.helper)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
        }
    }
}

struct DigitKeys: ViewModifier {
    @FocusState.Binding var focused: Bool
    let scale: ScalePoints
    let current: Int?
    let commit: (Int) -> Void
    let select: (Int) -> Void

    func body(content: Content) -> some View {
        content
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onKeyPress(characters: .decimalDigits, phases: .down) { press in
                guard press.modifiers.isDisjoint(with: [.command, .control, .option]), let key = press.characters.first,
                    let point = scale.point(forDigit: key)
                else { return .ignored }
                commit(point)
                return .handled
            }
            .onKeyPress(.leftArrow) { move(-1) }
            .onKeyPress(.rightArrow) { move(1) }
    }

    private func move(_ step: Int) -> KeyPress.Result {
        let next = (current ?? (step > 0 ? scale.low - 1 : scale.high + 1)) + step
        guard scale.points.contains(next) else { return .ignored }
        select(next)
        return .handled
    }
}

private struct ScaleInput: ViewModifier {
    @Environment(\.formhausTokens) private var tokens
    let context: FieldContext
    let scale: ScalePoints
    let current: Int?
    let focused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .disabled(context.isLocked)
            .overlay(FocusRing(visible: focused.wrappedValue, radius: tokens.radii.control, offset: 2))
            .modifier(
                DigitKeys(
                    focused: focused, scale: scale, current: current, commit: { context.commit(.number(Double($0))) },
                    select: { context.setValue(.number(Double($0))) })
            )
            .formhausFocus(context, focused)
    }
}

extension View {
    func scaleInput(_ context: FieldContext, _ scale: ScalePoints, _ current: Int?, _ focused: FocusState<Bool>.Binding) -> some View {
        modifier(ScaleInput(context: context, scale: scale, current: current, focused: focused))
    }
}

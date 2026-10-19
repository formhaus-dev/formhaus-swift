@_spi(Renderer) import FormhausCore
import SwiftUI

struct FormProgress: View {
    @Environment(\.formhausComponents) private var components
    @Environment(\.formhausBehavior) private var behavior
    let model: FormModel

    var body: some View {
        let structure = model.structure
        if structure.isMultiStep {
            let context = ProgressContext(
                current: structure.progress.current, total: structure.progress.total,
                counterLabel: model.label(
                    "stepOf", ["current": .number(Double(structure.progress.current)), "total": .number(Double(structure.progress.total))]),
                stepTitle: structure.currentStep?.title, stepDescription: structure.currentStep?.description, steps: marks(structure))
            if let custom = components.slots.progress {
                custom(context)
            } else {
                StepProgressView(context: context, focusRequest: model.focusRequest)
            }
        }
    }

    private func marks(_ structure: FormStructure) -> [StepStatus]? {
        guard behavior.stepErrorMarks else { return nil }
        let counts = model.stepErrorCounts
        return structure.steps.enumerated().map { index, step in
            let count = counts[step.id] ?? 0
            return StepStatus(
                id: step.id, title: step.title ?? model.label("stepTitle", ["index": .number(Double(index + 1))]), errorCount: count,
                errorLabel: count > 0 ? model.label("stepErrors", ["count": .number(Double(count))]) : nil)
        }
    }
}

public struct StepProgressView: View {
    @Environment(\.formhausTokens) private var tokens
    @AccessibilityFocusState private var headingFocused: Bool
    let context: ProgressContext
    let focusRequest: FocusRequest?

    public init(context: ProgressContext, focusRequest: FocusRequest? = nil) {
        self.context = context
        self.focusRequest = focusRequest
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacing.s2) {
            ProgressBar(fraction: context.total > 0 ? Double(context.current) / Double(context.total) : 0)
            Text(context.counterLabel).formhausText(.counter)
            if let steps = context.steps {
                FlowLayout(spacing: tokens.spacing.s7) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        StepMark(step: step, current: index + 1 == context.current)
                    }
                }
            }
            if let title = context.stepTitle, !title.isEmpty {
                Text(title).formhausText(.title).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, tokens.spacing.s1)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($headingFocused)
            }
            if let description = context.stepDescription, !description.isEmpty {
                Text(description).formhausText(.body).foregroundStyle(tokens.colors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: focusRequest) { _, request in
            if let request, request.key == nil { headingFocused = true }
        }
    }
}

private struct ProgressBar: View {
    @Environment(\.formhausTokens) private var tokens
    let fraction: Double

    var body: some View {
        Capsule()
            .fill(tokens.colors.backgroundDisabled)
            .frame(height: tokens.controls.progressHeight)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(tokens.colors.primary).frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
            }
            .clipShape(Capsule())
            .animation(tokens.animation(tokens.motion.progress), value: fraction)
            .accessibilityHidden(true)
    }
}

private struct StepMark: View {
    @Environment(\.formhausTokens) private var tokens
    let step: StepStatus
    let current: Bool

    var body: some View {
        HStack(spacing: tokens.spacing.s1) {
            Text(step.title).fontWeight(current ? .semibold : .regular)
            if let errors = step.errorLabel {
                Text(verbatim: "·").accessibilityHidden(true)
                Text(errors)
            }
        }
        .formhausText(.counter, colored: false)
        .foregroundStyle(step.errorCount > 0 ? tokens.colors.error : current ? tokens.colors.text : tokens.colors.textMuted)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(current ? .isSelected : [])
    }
}

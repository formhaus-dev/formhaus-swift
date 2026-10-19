@_spi(Renderer) import FormhausCore
import SwiftUI

struct FormActionsSlot: View {
    @Environment(\.formhausComponents) private var components
    let model: FormModel

    var body: some View {
        let context = ActionsContext(state: model.actions, busy: model.disabled, model: model)
        if let custom = components.slots.actions {
            custom(context)
        } else {
            FormActionsBar(context: context)
        }
    }
}

public struct FormActionsBar: View {
    @Environment(\.formhausTokens) private var tokens
    let context: ActionsContext

    public init(context: ActionsContext) {
        self.context = context
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: tokens.spacing.s3) {
                secondary
                Spacer(minLength: tokens.spacing.s3)
                primary.fixedSize()
            }
            .frame(minWidth: tokens.controls.compactWidth)
            VStack(spacing: tokens.spacing.s3) {
                if hasSecondary {
                    HStack(spacing: tokens.spacing.s3) { secondary }.frame(maxWidth: .infinity, alignment: .leading)
                }
                primary.frame(maxWidth: .infinity)
            }
        }
        .padding(.top, tokens.spacing.s1)
    }

    private var state: FormActionsState { context.state }

    private var hasSecondary: Bool {
        state.showBack || state.cancelAction != nil || state.showSkip
    }

    @ViewBuilder private var secondary: some View {
        if state.showBack {
            Button(state.backLabel, action: context.back)
                .buttonStyle(FormButtonStyle(FormButtonVariant(state.backAction, fallback: .secondary)))
                .disabled(context.busy)
        }
        if let cancel = state.cancelAction {
            Button(cancel.label ?? "", action: context.cancel)
                .buttonStyle(FormButtonStyle(FormButtonVariant(cancel, fallback: .text)))
                .disabled(context.busy)
        }
        if state.showSkip {
            Button(state.skipLabel, action: context.skip)
                .buttonStyle(FormButtonStyle(FormButtonVariant(state.skipAction, fallback: .text)))
                .disabled(context.busy)
        }
    }

    @ViewBuilder private var primary: some View {
        if state.showPrimary {
            Button(action: context.primary) {
                Text(state.primaryLabel).frame(maxWidth: .infinity)
            }
            .buttonStyle(FormButtonStyle(.primary, busy: context.busy && !context.model.loading))
            .disabled(context.busy || state.primaryDisabled)
            .keyboardShortcut(.defaultAction)
        }
    }
}

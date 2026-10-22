@_spi(Renderer) import FormhausCore
import SwiftUI

struct FormActionsSlot: View {
    @Environment(\.formhausComponents) private var components
    @Environment(\.formhausBehavior) private var behavior
    let model: FormModel

    var body: some View {
        let context = ActionsContext(state: model.actions, busy: model.disabled, model: model)
        if let custom = components.slots.actions {
            custom(context)
        } else {
            FormActionsBar(context: context).navigationBack(context, automatic: behavior.backPlacement == .automatic)
        }
    }
}

enum ActionsLayout {
    case stacked
    case row
}

extension EnvironmentValues {
    @Entry var formhausActionsLayout: ActionsLayout?
    @Entry var formhausBackInBar = false
}

public struct FormActionsBar: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.formhausActionsLayout) private var forcedLayout
    @Environment(\.formhausBackInBar) private var backInBar
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    let context: ActionsContext

    public init(context: ActionsContext) {
        self.context = context
    }

    public var body: some View {
        Group {
            if layout == .stacked {
                stacked
            } else {
                ViewThatFits(in: .horizontal) {
                    row
                    stacked
                }
            }
        }
        .padding(.top, tokens.spacing.s1)
    }

    private var layout: ActionsLayout {
        if let forcedLayout { return forcedLayout }
        #if os(iOS)
            return sizeClass == .compact ? .stacked : .row
        #else
            return .row
        #endif
    }

    private var row: some View {
        HStack(spacing: tokens.spacing.s3) {
            back(fill: false)
            textButtons
            Spacer(minLength: tokens.spacing.s3)
            primary.fixedSize()
        }
        .padding(.leading, leadingInset)
        .frame(minWidth: tokens.controls.compactWidth)
    }

    private var stacked: some View {
        VStack(spacing: tokens.spacing.s3) {
            primary.frame(maxWidth: .infinity)
            back(fill: true)
            if state.cancelAction != nil || state.showSkip {
                HStack(spacing: tokens.spacing.s3) { textButtons }.frame(maxWidth: .infinity)
            }
        }
    }

    private var state: FormActionsState { context.state }

    private var showsBack: Bool { state.showBack && !backInBar }

    private var leadingInset: CGFloat {
        let first: FormButtonVariant? =
            if showsBack {
                FormButtonVariant(state.backAction, fallback: .secondary)
            } else if let cancel = state.cancelAction {
                FormButtonVariant(cancel, fallback: .text)
            } else if state.showSkip {
                FormButtonVariant(state.skipAction, fallback: .text)
            } else {
                nil
            }
        return first == .text ? -tokens.spacing.s4 : 0
    }

    @ViewBuilder private func back(fill: Bool) -> some View {
        if showsBack {
            Button(action: context.back) {
                Text(verbatim: state.backLabel).frame(maxWidth: fill ? .infinity : nil)
            }
            .buttonStyle(FormButtonStyle(FormButtonVariant(state.backAction, fallback: .secondary)))
            .disabled(context.busy)
            .formhausTestId(context.testIds.back)
            .measured("actions/back")
        }
    }

    @ViewBuilder private var textButtons: some View {
        if let cancel = state.cancelAction {
            Button(cancel.label ?? "", action: context.cancel)
                .buttonStyle(FormButtonStyle(FormButtonVariant(cancel, fallback: .text)))
                .disabled(context.busy)
                .formhausTestId(context.testIds.cancel)
        }
        if state.showSkip {
            Button(state.skipLabel, action: context.skip)
                .buttonStyle(FormButtonStyle(FormButtonVariant(state.skipAction, fallback: .text)))
                .disabled(context.busy)
        }
    }

    @ViewBuilder private var primary: some View {
        if state.showPrimary {
            Button(action: context.performPrimaryAction) {
                Text(verbatim: state.primaryLabel).frame(maxWidth: .infinity)
            }
            .buttonStyle(FormButtonStyle(.primary, busy: context.busy && !context.model.loading))
            .disabled(context.busy || state.primaryDisabled)
            .keyboardShortcut(.defaultAction)
            .formhausTestId(context.primaryTestId)
            .measured("actions/primary")
        }
    }
}

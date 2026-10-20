@_spi(Renderer) import FormhausCore
import SwiftUI

struct SystemPrimaryButton: View {
    let context: ActionsContext
    var prominent = false

    var body: some View {
        if context.busy, !context.model.loading {
            ProgressView()
        } else if context.state.showPrimary {
            Button(action: context.performPrimaryAction) {
                Text(verbatim: label)
                    #if os(iOS)
                        .foregroundStyle(prominent || filled ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                        .frame(maxWidth: prominent ? .infinity : nil, minHeight: prominent ? 34 : nil)
                    #endif
            }
            .fontWeight(.semibold)
            .modifier(SystemProminence(prominent: prominent))
            .disabled(context.busy || context.state.primaryDisabled)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var label: String {
        let state = context.state
        if prominent || state.isLastStep { return state.primaryLabel }
        return state.nextAction?.label ?? context.model.text(forLabel: "next")
    }

    #if os(iOS)
        private var filled: Bool {
            if #available(iOS 26, *) { return true }
            return false
        }
    #endif
}

private struct SystemProminence: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content.buttonStyle(.borderedProminent).controlSize(.large)
        } else {
            #if os(iOS)
                if #available(iOS 26, *) { content.buttonStyle(.glassProminent) } else { content }
            #else
                content
            #endif
        }
    }
}

struct SystemSkip: View {
    let model: FormModel

    var body: some View {
        if model.actions.showSkip {
            Section {
                Button(model.actions.skipLabel) { Task { await model.skip() } }
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(model.disabled)
            }
            .listRowBackground(Color.clear)
        }
    }
}

#if os(iOS)
    struct SystemToolbar: ViewModifier {
        let context: ActionsContext
        let first: Bool
        let empty: Bool
        let custom: Bool

        func body(content: Content) -> some View {
            content
                .toolbar {
                    if !empty, !custom {
                        ToolbarItem(placement: .confirmationAction) { SystemPrimaryButton(context: context) }
                    }
                    if first, let cancel = context.state.cancelAction {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(cancel.label ?? "", role: .cancel, action: context.cancel).disabled(context.busy)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if empty, !custom {
                        SystemPrimaryButton(context: context, prominent: true).padding(.horizontal, 20).padding(.bottom, 8)
                    }
                }
                .navigationBarBackButtonHidden(context.model.disabled || context.model.stepValidating)
                .interactiveDismissDisabled(context.model.disabled || context.model.stepValidating)
        }
    }
#else
    struct SystemBottomRow: View {
        let context: ActionsContext

        var body: some View {
            Section {
                HStack(spacing: 12) {
                    if let cancel = context.state.cancelAction {
                        Button(cancel.label ?? "", role: .cancel, action: context.cancel).disabled(context.busy)
                    }
                    Spacer()
                    if context.state.showBack {
                        Button(context.state.backLabel, action: context.back).disabled(context.busy)
                    }
                    SystemPrimaryButton(context: context)
                }
                .controlSize(.large)
            }
            .listRowBackground(Color.clear)
        }
    }
#endif

@_spi(Renderer) import FormhausCore
import SwiftUI

@MainActor
public struct SectionContext {
    public let section: FormSection
    public let title: String
    public let description: String?
    public let content: AnyView
}

@MainActor
public struct GroupItemContext: Identifiable {
    public let id: String
    public let index: Int
    public let title: String
    public let canRemove: Bool
    public let hasContent: Bool
    public let removeLabel: String
    public let removeName: String
    public let disabled: Bool
    public let content: AnyView
    public let requestRemove: @MainActor () -> Void
    public let remove: @MainActor () -> Void
    let removeFocus: FieldState
    let model: FormModel
    let fields: [FormField]
}

@MainActor
public struct ConfirmContext {
    public let title: String
    public let message: String
    public let confirmLabel: String
    public let cancelLabel: String
    public let confirm: @MainActor () -> Void
    public let cancel: @MainActor () -> Void
}

@MainActor
public struct GroupContext {
    public let group: FormField
    public let label: String
    public let helperText: String?
    public let error: String?
    public let items: [GroupItemContext]
    public let canAdd: Bool
    public let addLabel: String
    public let disabled: Bool
    public let add: @MainActor () -> Void
    let model: FormModel
}

public struct StepStatus: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let errorCount: Int
    public let errorLabel: String?
}

@MainActor
public struct ProgressContext {
    public let current: Int
    public let total: Int
    public let counterLabel: String
    public let stepTitle: String?
    public let stepDescription: String?
    public let steps: [StepStatus]?
}

@MainActor
public struct ActionsContext {
    public let state: FormActionsState
    public let busy: Bool
    public let model: FormModel

    public func performPrimaryAction() { Task { await model.performPrimaryAction() } }
    public func back() { Task { await model.back() } }
    public func skip() { Task { await model.skip() } }
    public func cancel() { model.cancel() }
}

typealias SlotBuilder<Context> = @MainActor @Sendable (Context) -> AnyView

struct ContainerSlots: Sendable {
    var section: SlotBuilder<SectionContext>?
    var group: SlotBuilder<GroupContext>?
    var groupItem: SlotBuilder<GroupItemContext>?
    var confirm: SlotBuilder<ConfirmContext>?
    var progress: SlotBuilder<ProgressContext>?
    var actions: SlotBuilder<ActionsContext>?
}

extension FormComponents {
    public func section<Content: View>(@ViewBuilder _ content: @escaping @MainActor @Sendable (SectionContext) -> Content) -> Self {
        var copy = self
        copy.slots.section = { AnyView(content($0)) }
        return copy
    }

    public func group<Content: View>(@ViewBuilder _ content: @escaping @MainActor @Sendable (GroupContext) -> Content) -> Self {
        var copy = self
        copy.slots.group = { AnyView(content($0)) }
        return copy
    }

    public func groupItem<Content: View>(@ViewBuilder _ content: @escaping @MainActor @Sendable (GroupItemContext) -> Content) -> Self {
        var copy = self
        copy.slots.groupItem = { AnyView(content($0)) }
        return copy
    }

    public func confirmDialog<Content: View>(@ViewBuilder _ content: @escaping @MainActor @Sendable (ConfirmContext) -> Content) -> Self {
        var copy = self
        copy.slots.confirm = { AnyView(content($0)) }
        return copy
    }

    public func progress<Content: View>(@ViewBuilder _ content: @escaping @MainActor @Sendable (ProgressContext) -> Content) -> Self {
        var copy = self
        copy.slots.progress = { AnyView(content($0)) }
        return copy
    }

    public func actions<Content: View>(@ViewBuilder _ content: @escaping @MainActor @Sendable (ActionsContext) -> Content) -> Self {
        var copy = self
        copy.slots.actions = { AnyView(content($0)) }
        return copy
    }
}

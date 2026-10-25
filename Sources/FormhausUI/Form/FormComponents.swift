import SwiftUI

typealias FieldViewBuilder = @MainActor @Sendable (FieldContext) -> AnyView

public struct FormComponents: Sendable {
    var fields: [String: FieldViewBuilder] = [:]
    var slots = ContainerSlots()
    let builtIns: Bool
    var system = false

    public static let standard = FormComponents(builtIns: true)
    public static let headless = FormComponents(builtIns: false)
    public static let system = FormComponents(builtIns: true, system: true)

    public func field<Content: View>(
        _ type: String, @ViewBuilder _ content: @escaping @MainActor @Sendable (FieldContext) -> Content
    ) -> FormComponents {
        var copy = self
        copy.fields[type] = { AnyView(content($0)) }
        return copy
    }
}

public enum BackPlacement: Sendable {
    case automatic
    case bottom
}

public enum StepScroll: Sendable {
    case screenTop
    case formTop
}

public enum TitleDisplayMode: Sendable {
    case automatic
    case inline
    case large
    case off
}

public struct FormBehavior: Sendable {
    public var errorSummary = true
    public var confirmRemove = true
    public var stepErrorMarks = false
    public var backPlacement = BackPlacement.automatic
    public var stepScroll = StepScroll.screenTop
    public var inlineChoiceLimit = 6
    public var titleDisplayMode = TitleDisplayMode.automatic
    public var conditionalReveal = false

    public init(
        errorSummary: Bool = true, confirmRemove: Bool = true, stepErrorMarks: Bool = false,
        backPlacement: BackPlacement = .automatic, stepScroll: StepScroll = .screenTop, inlineChoiceLimit: Int = 6,
        titleDisplayMode: TitleDisplayMode = .automatic, conditionalReveal: Bool = false
    ) {
        self.errorSummary = errorSummary
        self.confirmRemove = confirmRemove
        self.stepErrorMarks = stepErrorMarks
        self.backPlacement = backPlacement
        self.stepScroll = stepScroll
        self.inlineChoiceLimit = inlineChoiceLimit
        self.titleDisplayMode = titleDisplayMode
        self.conditionalReveal = conditionalReveal
    }
}

extension EnvironmentValues {
    @Entry public var formhausComponents = FormComponents.standard
    @Entry public var formhausBehavior = FormBehavior()
}

extension View {
    public func formhausComponents(_ components: FormComponents) -> some View {
        environment(\.formhausComponents, components)
    }

    public func formhausBehavior(_ behavior: FormBehavior) -> some View {
        environment(\.formhausBehavior, behavior)
    }

    public func formhausBehavior(stepScroll: StepScroll) -> some View {
        transformEnvironment(\.formhausBehavior) { $0.stepScroll = stepScroll }
    }
}

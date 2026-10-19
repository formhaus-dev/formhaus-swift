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

public struct FormBehavior: Sendable {
    public var errorSummary = false
    public var confirmRemove = true
    public var stepErrorMarks = false

    public init(errorSummary: Bool = false, confirmRemove: Bool = true, stepErrorMarks: Bool = false) {
        self.errorSummary = errorSummary
        self.confirmRemove = confirmRemove
        self.stepErrorMarks = stepErrorMarks
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
}

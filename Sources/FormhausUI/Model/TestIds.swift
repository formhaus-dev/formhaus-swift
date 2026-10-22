@_spi(Renderer) import FormhausCore
import SwiftUI

public enum TestIds: Sendable {
    case off
    case automatic
    case custom(@MainActor @Sendable (TestIdTarget) -> String?)
}

public struct ActionTestIds: Sendable, Hashable {
    public let submit: String?
    public let next: String?
    public let back: String?
    public let cancel: String?
}

extension FormModel {
    func testId(_ kind: TestIdTarget.Kind, key: String? = nil, value: String? = nil) -> String? {
        let target = TestIdTarget(kind: kind, definitionId: engine.definition.id, key: key, value: value)
        switch options.testIds {
        case .off: return nil
        case .automatic: return target.defaultId
        case .custom(let name): return name(target)
        }
    }
}

extension FieldContext {
    public var testId: String? { model.testId(.field, key: key) }

    public func optionTestId(_ value: String) -> String? {
        model.testId(.option, key: key, value: value)
    }
}

extension ActionsContext {
    public var testIds: ActionTestIds {
        ActionTestIds(submit: model.testId(.submit), next: model.testId(.next), back: model.testId(.back), cancel: model.testId(.cancel))
    }

    var primaryTestId: String? {
        model.testId(state.isLastStep ? .submit : .next)
    }
}

extension View {
    @ViewBuilder
    func formhausTestId(_ id: String?) -> some View {
        if let id { accessibilityIdentifier(id) } else { self }
    }

    @ViewBuilder
    func formhausTestContainer(_ id: String?) -> some View {
        if let id { accessibilityElement(children: .contain).accessibilityIdentifier(id) } else { self }
    }
}

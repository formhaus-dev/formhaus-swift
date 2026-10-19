@_spi(Renderer) import FormhausCore
import SwiftUI

@MainActor
public struct FieldContext {
    public let field: FormField
    public let key: String
    public let value: JSONValue?
    public let error: String?
    public let loading: Bool
    public let disabled: Bool
    public let options: [FieldOption]
    public let model: FormModel
    let state: FieldState

    public init(field: FormField, key: String? = nil, model: FormModel) {
        let key = key ?? field.key
        self.init(field: field, key: key, state: model.field(key), model: model)
    }

    init(field: FormField, key: String, state: FieldState, model: FormModel) {
        self.field = field
        self.key = key
        self.state = state
        self.model = model
        value = state.value
        error = state.error
        loading = state.loading
        disabled = model.disabled
        options = model.options(for: key) ?? field.options ?? []
    }

    public var isItem: Bool { key != field.key }
    public var isInvalid: Bool { error?.isEmpty == false }
    public var isLocked: Bool { disabled || loading }
    public var label: String { field.label ?? "" }
    public var accessibilityName: String {
        isRequired ? "\(label), \(text(forLabel: "required"))" : label
    }

    public var helperText: String? { field.helperText.flatMap { $0.isEmpty ? nil : $0 } }
    public var isRequired: Bool { field.isRequired }
    public var advancesOnCommit: Bool { !isItem && field.advancesOnCommit }

    public var text: String {
        switch value {
        case .string(let text)?: text
        case .number(let number)?: numberText(number)
        case .bool(let flag)?: flag ? "true" : "false"
        default: ""
        }
    }

    public func setValue(_ value: JSONValue?) {
        model.setValue(value, forKey: key)
    }

    public func commit(_ value: JSONValue?) {
        if advancesOnCommit {
            model.commitValue(value, forKey: key)
        } else {
            model.setValue(value, forKey: key)
        }
    }

    public func performPrimaryAction() {
        Task { await model.performPrimaryAction() }
    }

    public func text(forLabel key: String, _ params: JSONObject = JSONObject()) -> String {
        model.text(forLabel: key, params)
    }

    public var textBinding: Binding<String> {
        Binding(get: { text }, set: { setValue(.string($0)) })
    }

    public var boolBinding: Binding<Bool> {
        Binding(get: { value?.boolValue == true }, set: { setValue(.bool($0)) })
    }
}

func numberText(_ number: Double) -> String {
    number.rounded() == number && abs(number) < 1e15 ? String(Int(number)) : String(number)
}

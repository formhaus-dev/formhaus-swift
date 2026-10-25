@_spi(Renderer) import FormhausCore
import SwiftUI

private let countedTypes: Set = ["text", "email", "phone", "password", "textarea"]

@MainActor
public struct FieldContext {
    public let field: FormField
    public let key: String
    public let value: JSONValue?
    public let error: String?
    public let loading: Bool
    public let disabled: Bool
    let focused: Bool
    public let options: [FieldOption]
    public let model: FormModel
    public let label: String
    public let placeholder: String?
    private let helper: String?
    let state: FieldState
    let reveals: [FieldReveal]

    public init(field: FormField, key: String? = nil, model: FormModel) {
        let key = key ?? field.key
        self.init(field: field, key: key, state: model.field(key), model: model)
    }

    init(field: FormField, key: String, state: FieldState, model: FormModel, reveals: [FieldReveal] = []) {
        self.field = field
        self.reveals = reveals
        let texts = model.texts(for: field, at: key)
        label = texts.label ?? ""
        placeholder = texts.placeholder
        helper = texts.helperText
        self.key = key
        self.state = state
        self.model = model
        value = state.value
        error = state.error
        loading = state.loading
        disabled = model.disabled
        focused = state.hasFocus
        let loaded = model.options(for: key)
        options = field.randomize ? model.engine.orderOptions(key, options: loaded) : loaded ?? field.options ?? []
    }

    public var isItem: Bool { key != field.key }
    public var isInvalid: Bool { error?.isEmpty == false }
    public var isLocked: Bool { loading || disabled && !focused }
    public var accessibilityName: String {
        isRequired ? "\(label), \(text(forLabel: "required"))" : label
    }

    public var helperText: String? { helper.flatMap { $0.isEmpty ? nil : $0 } }
    public var minLength: Double? { countedTypes.contains(field.type) ? field.validation?.minLength : nil }
    public var maxLength: Double? { countedTypes.contains(field.type) ? field.validation?.maxLength : nil }
    public var isRequired: Bool { field.isRequired }
    public var advancesOnCommit: Bool { !isItem && field.advancesOnCommit }

    public var text: String { displayText(value) }

    var pendingText: String { displayText(model.pendingValue(forKey: key)) }

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
        Binding(get: { text }, set: { if $0 != pendingText { setValue(.string($0)) } })
    }

    public var boolBinding: Binding<Bool> {
        Binding(get: { value?.boolValue == true }, set: { setValue(.bool($0)) })
    }
}

private func displayText(_ value: JSONValue?) -> String {
    switch value {
    case .string(let text)?: text
    case .number(let number)?: numberText(number)
    case .bool(let flag)?: flag ? "true" : "false"
    default: ""
    }
}

func numberText(_ number: Double) -> String {
    number.rounded() == number && abs(number) < 1e15 ? String(Int(number)) : String(number)
}

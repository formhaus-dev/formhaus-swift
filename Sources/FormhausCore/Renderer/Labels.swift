import Foundation

public typealias LabelFn = @Sendable (String, JSONObject) -> String?

public enum LabelSource: Sendable {
    case catalog(JSONValue)
    case function(LabelFn)
}

func labelFor(_ key: String, _ params: JSONObject = JSONObject(), _ sources: LabelSource?...) -> String {
    for source in sources {
        switch source {
        case .function(let resolve)?:
            if let text = resolve(key, params), !text.isEmpty { return text }
        case .catalog(let catalog)?:
            if let text = catalog[key]?.stringValue, !text.isEmpty { return formatText(text, params) }
        case nil:
            continue
        }
    }
    return formatText(defaultLabels[key] ?? "", params)
}

public struct ErrorEntry: Sendable, Hashable, Identifiable {
    public let key: String
    public let label: String
    public let message: String

    public var id: String { key }

    public var text: String {
        let closing = label.precomposedStringWithCompatibilityMapping.unicodeScalars.last.map { closingPunctuation.contains($0) } ?? false
        return label + (closing ? " " : ": ") + message
    }
}

public struct ErrorGroup: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let entries: [ErrorEntry]
}

private let closingPunctuation = Set("?!:.\u{3002}".unicodeScalars)

public struct FormActionsState: Sendable, Hashable {
    public let submitAction: FormAction
    public let nextAction: FormAction?
    public let backAction: FormAction?
    public let skipAction: FormAction?
    public let cancelAction: FormAction?
    public let isFirstStep: Bool
    public let isLastStep: Bool
    public let isMultiStep: Bool
    public let primaryLabel: String
    public let primaryDisabled: Bool
    public let showPrimary: Bool
    public let showBack: Bool
    public let backLabel: String
    public let showSkip: Bool
    public let skipLabel: String
}

extension FormEngine {
    private var definitionLabels: LabelSource? {
        definition.labels.map { .catalog($0) }
    }

    @_spi(Renderer)
    public func label(_ key: String, _ source: LabelSource?, _ params: JSONObject = JSONObject()) -> String {
        labelFor(key, params, source, definitionLabels)
    }

    @_spi(Renderer)
    public func itemTitle(_ group: FormField, _ index: Int, _ source: LabelSource?) -> String {
        let params: JSONObject = ["label": group.label.map { .string($0) } ?? .null, "index": .number(Double(index + 1))]
        if let template = group.itemLabel { return formatText(template, params) }
        return label("itemLabel", source, params)
    }

    @_spi(Renderer)
    public func errorGroups(_ source: LabelSource?) -> [ErrorGroup] {
        let errors = core.errors
        guard !errors.isEmpty else { return [] }
        let values = core.values.json
        let sections: [(id: String, title: String?, fields: [FormNode])] =
            isMultiStep ? visibleSteps.map { ($0.id, $0.title, $0.fields) } : [(definition.id, definition.title, definition.fields ?? [])]
        return sections.enumerated().compactMap { index, section in
            let entries = errorKeys(section.fields, errors, values).compactMap { key -> ErrorEntry? in
                let item = core.visibility.activeItem(key, values)
                guard let field = item?.field ?? core.visibility.activeField(key, values), let message = errors[key] else { return nil }
                let name = field.label ?? ""
                let label = item.map { "\(name) (\(itemTitle($0.group, $0.index, source)))" } ?? name
                return ErrorEntry(key: key, label: label, message: message)
            }
            guard !entries.isEmpty else { return nil }
            let title = section.title.flatMap { $0.isEmpty ? nil : $0 } ?? label("stepTitle", source, ["index": .number(Double(index + 1))])
            return ErrorGroup(id: section.id, title: title, entries: entries)
        }
    }

    @_spi(Renderer)
    public func actionsState(_ source: LabelSource?) -> FormActionsState {
        let step = currentStep
        let last = isLastStep || !isMultiStep
        let next = step?.next ?? .absent
        let primaryAction = last ? definition.submit : next.action
        return FormActionsState(
            submitAction: definition.submit, nextAction: next.action, backAction: step?.back.action, skipAction: step?.skip.action,
            cancelAction: definition.cancel, isFirstStep: isFirstStep, isLastStep: last, isMultiStep: isMultiStep,
            primaryLabel: last
                ? definition.submit.label ?? label("submit", source) : next.action?.label ?? label("continue", source),
            primaryDisabled: isActionDisabled(primaryAction),
            showPrimary: last || next != .hidden,
            showBack: isMultiStep && !isFirstStep && step?.back != .hidden,
            backLabel: step?.back.action?.label ?? label("back", source),
            showSkip: step?.canSkip == true && next != .hidden,
            skipLabel: step?.skip.action?.label ?? label("skip", source)
        )
    }
}

@_spi(Renderer)
public func formatTemplate(_ template: String, _ params: JSONObject) -> String {
    formatText(template, params)
}

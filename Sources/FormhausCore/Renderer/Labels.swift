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
    @_spi(Renderer)
    public func label(_ key: String, _ source: LabelSource?, _ params: JSONObject = JSONObject(), locale: [LocaleCatalog]? = nil) -> String
    {
        #if DEBUG
            reportMissingLabel(key, source, definition, locale ?? core.locale, options)
        #endif
        return resolvedLabel(key, source, params, locale: locale)
    }

    private func resolvedLabel(
        _ key: String, _ source: LabelSource?, _ params: JSONObject = JSONObject(), locale: [LocaleCatalog]? = nil
    ) -> String {
        labelFor(key, params, source, definition.labels.map { .catalog($0) }, localeLabels(locale ?? core.locale))
    }

    private func label(_ key: String, _ source: LabelSource?, shown: Bool) -> String {
        shown ? label(key, source) : resolvedLabel(key, source)
    }

    @_spi(Renderer)
    public func itemTitle(_ group: FormField, _ index: Int, _ source: LabelSource?) -> String {
        let name = recalled(group).label
        let params: JSONObject = ["label": name.map { .string($0) } ?? .null, "index": .number(Double(index + 1))]
        if let template = group.itemLabel { return itemTemplate(template, RecallItem(group: group.key, index: index), params) }
        return cut(label("itemLabel", source, params))
    }

    @_spi(Renderer)
    public func actionsState(_ source: LabelSource?) -> FormActionsState {
        let step = currentStep
        let last = isLastStep || !isMultiStep
        let next = step?.next ?? .absent
        let primaryAction = last ? definition.submit : next.action
        let showBack = isMultiStep && !isFirstStep && step?.back != .hidden
        let showSkip = step?.canSkip == true && next != .hidden
        return FormActionsState(
            submitAction: definition.submit, nextAction: next.action, backAction: step?.back.action, skipAction: step?.skip.action,
            cancelAction: definition.cancel, isFirstStep: isFirstStep, isLastStep: last, isMultiStep: isMultiStep,
            primaryLabel: last
                ? definition.submit.label ?? label("submit", source) : next.action?.label ?? label("continue", source),
            primaryDisabled: isActionDisabled(primaryAction),
            showPrimary: last || next != .hidden,
            showBack: showBack,
            backLabel: step?.back.action?.label ?? label("back", source, shown: showBack),
            showSkip: showSkip,
            skipLabel: step?.skip.action?.label ?? label("skip", source, shown: showSkip)
        )
    }
}

@_spi(Renderer)
public func formatTemplate(_ template: String, _ params: JSONObject) -> String {
    formatText(template, params)
}

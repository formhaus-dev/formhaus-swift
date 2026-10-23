@_spi(Renderer) import FormhausCore

private let upcomingLabels: [String: String] = [
    "next": "Next",
    "select": "Select",
]

extension FormModel {
    public func text(forLabel key: String, _ params: JSONObject = JSONObject()) -> String {
        let text = engine.label(key, options.labels, params, locale: locale)
        guard text.isEmpty, let fallback = upcomingLabels[key] else { return text }
        return formatTemplate(fallback, params)
    }

    func errorText(forKey key: String) -> String? {
        errorGroups.lazy.flatMap(\.entries).first { $0.key == key }?.text
    }
}

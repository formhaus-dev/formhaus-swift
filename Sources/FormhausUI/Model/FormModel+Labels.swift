@_spi(Renderer) import FormhausCore

extension FormModel {
    public func text(forLabel key: String, _ params: JSONObject = JSONObject()) -> String {
        engine.label(key, options.labels, params, locale: locale)
    }

    func errorText(forKey key: String) -> String? {
        errorGroups.lazy.flatMap(\.entries).first { $0.key == key }?.text
    }
}

import Foundation

private let pluralParams = ["count", "min", "max"]

private func slavicCategory(_ integer: Double) -> String {
    let ten = integer.truncatingRemainder(dividingBy: 10)
    let hundred = integer.truncatingRemainder(dividingBy: 100)
    if ten == 1 && hundred != 11 { return "one" }
    return (2...4).contains(ten) && !(12...14).contains(hundred) ? "few" : "many"
}

func pluralCategory(_ number: Double, _ locale: Locale) -> String {
    guard number.isFinite else { return "other" }
    let milli = (abs(number) * 1000).rounded()
    let fraction = Int(milli.truncatingRemainder(dividingBy: 1000))
    let integer = (milli / 1000).rounded(.down)
    let digits = fraction == 0 ? 0 : fraction % 100 == 0 ? 1 : fraction % 10 == 0 ? 2 : 3
    let millions = digits == 0 && integer != 0 && integer.truncatingRemainder(dividingBy: 1_000_000) == 0
    let language = locale.language.languageCode?.identifier ?? ""
    let rules = language == "pt" && locale.region?.identifier == "PT" ? "it" : language
    switch rules {
    case "en", "de": return integer == 1 && digits == 0 ? "one" : "other"
    case "es", "it": return integer == 1 && digits == 0 ? "one" : millions ? "many" : "other"
    case "fr", "pt": return integer <= 1 ? "one" : millions ? "many" : "other"
    case "ru", "uk": return digits == 0 ? slavicCategory(integer) : "other"
    default: return "other"
    }
}

private func catalogText(_ tag: String, _ text: LocaleText, _ params: JSONObject) -> String {
    var values = params
    var category = "other"
    if let name = pluralParams.first(where: { params[$0]?.numberValue != nil }), let number = params[name]?.numberValue {
        let locale = recallLocale(tag)
        category = pluralCategory(number, locale)
        values[name] = .string(formatNumber(number, locale))
    }
    switch text {
    case .text(let template): return formatText(template, values)
    case .plural(let forms): return formatText(forms[category], values)
    }
}

private func localeText(_ catalogs: [LocaleCatalog], _ params: JSONObject, _ text: (LocaleCatalog) -> LocaleText?) -> String? {
    for catalog in catalogs {
        if let text = text(catalog).map({ catalogText(catalog.locale, $0, params) }), !text.isEmpty { return text }
    }
    return nil
}

func localeMessages(_ catalogs: [LocaleCatalog]) -> MessageSource? {
    catalogs.isEmpty ? nil : .function { key, params, _ in localeText(catalogs, params) { $0.messages[key] } }
}

func localeLabels(_ catalogs: [LocaleCatalog]) -> LabelSource? {
    catalogs.isEmpty ? nil : .function { key, params in localeText(catalogs, params) { $0.labels[key] } }
}

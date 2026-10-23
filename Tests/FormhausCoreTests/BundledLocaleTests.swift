import Foundation
import Testing

@testable import FormhausCore

private let tags = LocaleCatalog.bundledFiles.map { $0.deletingPathExtension().lastPathComponent }.sorted()
private let samples: [Double] = [0, 1, 2, 3, 5, 11, 21, 22, 25, 101, 1_000_000, 1.5]

private func tokens(_ text: String) -> [String] {
    text.matches(of: /\{(\w+)\}/).map { String($0.1) }.sorted()
}

private func forms(_ text: LocaleText) -> [String] {
    switch text {
    case .text(let text): [text]
    case .plural(let forms): [forms.zero, forms.one, forms.two, forms.few, forms.many, forms.other].compactMap { $0 }
    }
}

private func categories(_ text: LocaleText) -> Set<String> {
    guard case .plural(let forms) = text else { return [] }
    let named = ["zero": forms.zero, "one": forms.one, "two": forms.two, "few": forms.few, "many": forms.many]
    return Set(named.compactMap { $0.value == nil ? nil : $0.key } + ["other"])
}

private func texts(_ catalog: LocaleCatalog) -> [(key: String, text: LocaleText, english: String)] {
    catalog.messages.map { ($0.key.rawValue, $0.value, defaultMessages[$0.key] ?? "") }
        + catalog.labels.map { ($0.key, $0.value, defaultLabels[$0.key] ?? "") }
}

@Suite("Bundled locale catalogs")
struct BundledLocaleTests {
    @Test("ships the first set of languages")
    func shipped() {
        #expect(tags == ["de", "en", "es", "fr", "fr-CA", "it", "ja", "pt-BR", "ru", "uk", "zh-CN"])
        #expect(LocaleCatalog.bundled("xx") == nil)
        #expect(LocaleCatalog.bundled("../locales/en") == nil)
    }

    @Test("keeps the English catalog equal to the built-in texts")
    func english() throws {
        let english = try #require(LocaleCatalog.bundled("en"))
        #expect(english.messages == defaultMessages.mapValues { .text($0) })
        #expect(english.labels == defaultLabels.mapValues { .text($0) })
    }

    @Test("names its file and has every key", arguments: tags)
    func complete(tag: String) throws {
        let file = try #require(LocaleCatalog.bundledFiles.first { $0.deletingPathExtension().lastPathComponent == tag })
        #expect(checkCatalog(try JSONValue(parsing: Data(contentsOf: file))) == CatalogIssues(missing: [], unknown: []))
        let catalog = try #require(LocaleCatalog.bundled(tag))
        #expect(catalog.locale == tag)
        #expect(localeChain(tag).contains(tag))
        #expect(catalog.messages.count == defaultMessages.count && catalog.labels.count == defaultLabels.count)
    }

    @Test("keeps the placeholders of the English texts and has trimmed texts", arguments: tags)
    func placeholders(tag: String) throws {
        for entry in texts(try #require(LocaleCatalog.bundled(tag))) {
            for form in forms(entry.text) {
                #expect(tokens(form) == tokens(entry.english), "\(entry.key): \(form)")
                #expect(form.trimmingCharacters(in: .whitespacesAndNewlines) == form, "\(entry.key)")
            }
        }
    }

    @Test("has exactly the plural forms of its language", arguments: tags)
    func plurals(tag: String) throws {
        let language = Locale(identifier: tag).language.languageCode?.identifier ?? ""
        let expected = Set(samples.map { pluralCategory($0, language) })
        for entry in texts(try #require(LocaleCatalog.bundled(tag))) where categories(entry.text) != [] {
            #expect(categories(entry.text) == expected, "\(entry.key)")
        }
    }

    @Test("loads the catalogs of the fallback chain and leaves English to the built-in texts")
    func chain() {
        let locales = { (tag: String) in localeChain(tag).filter { $0 != "en" }.compactMap(LocaleCatalog.bundled).map(\.locale) }
        #expect(locales("fr-CA") == ["fr-CA", "fr"])
        #expect(locales("ru-RU") == ["ru"])
        #expect(locales("zh-Hans-CN") == ["zh-CN"])
        #expect(locales("pt") == ["pt-BR"])
        #expect(locales("en-GB").isEmpty)
    }
}

@Suite("localeChain and checkCatalog")
struct LocaleChainTests {
    @Test(
        "adds the likely region and ends with English",
        arguments: [
            ("ja-JP", ["ja-JP", "ja", "en"]), ("zh-hant-tw", ["zh-Hant-TW", "zh-Hant", "zh-TW", "zh", "en"]),
            ("zh-Hans-CN", ["zh-Hans-CN", "zh-Hans", "zh-CN", "zh", "en"]), ("zh-Hant", ["zh-Hant", "zh-TW", "zh", "en"]),
            ("zh", ["zh", "zh-CN", "en"]), ("pt", ["pt", "pt-BR", "en"]), ("pt_br", ["pt-BR", "pt", "en"]), ("en-US", ["en-US", "en"]),
            ("en", ["en-US", "en"]), ("en-US-u-va-posix", ["en-US", "en"]), ("de-CH-u-co-phonebk", ["de-CH", "de", "en"]),
            ("", ["en"]), ("not a tag", ["en"]),
        ])
    func chain(tag: String, expected: [String]) {
        #expect(localeChain(tag) == expected)
    }

    @Test("lists missing and unknown keys")
    func issues() {
        var messages = JSONObject()
        for (key, text) in defaultMessages { messages[key.rawValue] = .string(text) }
        messages["minLength"] = ["one": "x", "several": "y"]
        messages["typo"] = "z"
        var labels = JSONObject()
        for (key, text) in defaultLabels { labels[key] = .string(text) }
        labels["back"] = " "
        let catalog: JSONValue = ["locale": "ru", "region": "RU", "messages": .object(messages), "labels": .object(labels)]
        #expect(
            checkCatalog(catalog)
                == CatalogIssues(
                    missing: ["messages.minLength.other", "labels.back"],
                    unknown: ["region", "messages.minLength.several", "messages.typo"]))
    }

    @Test("reports everything for a non-object")
    func empty() {
        #expect(checkCatalog(nil).missing.count == 1 + defaultMessages.count + defaultLabels.count)
        #expect(checkCatalog(["locale": 1]).missing.first == "locale")
    }
}
